package com.allensu.grokmode.voice

import android.util.Base64
import android.util.Log
import com.allensu.grokmode.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import okhttp3.*
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.TimeUnit
import kotlin.coroutines.resume
import kotlin.coroutines.resumeWithException

sealed class VoiceEvent {
    object SessionCreated : VoiceEvent()
    object SessionConfigured : VoiceEvent()
    object UserSpeechStarted : VoiceEvent()
    object UserSpeechStopped : VoiceEvent()
    data class AssistantSpeaking(val itemId: String?) : VoiceEvent()
    data class AudioDelta(val audioData: ByteArray) : VoiceEvent()
    data class Error(val message: String) : VoiceEvent()
    object Other : VoiceEvent()
}

class XAIVoiceService {

    companion object {
        private const val TAG = "XAIVoiceService"
        private const val PROXY_URL = "https://grokmode-proxy.aziz-albahar.workers.dev/grok/v1/realtime/client_secrets"
        private const val XAI_REALTIME_URL = "wss://api.x.ai/v1/realtime"
        const val SAMPLE_RATE = 24000
    }

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(30, TimeUnit.SECONDS)
        .pingInterval(30, TimeUnit.SECONDS)
        .build()

    private var webSocket: WebSocket? = null
    private var ephemeralToken: String? = null

    var onConnected: (() -> Unit)? = null
    var onEvent: ((VoiceEvent) -> Unit)? = null
    var onError: ((Exception) -> Unit)? = null
    var onDisconnected: ((Exception?) -> Unit)? = null

    private val instructions = """
        You are a helpful voice assistant for GrokMode, a voice-powered app for X (Twitter).
        Keep responses concise and conversational since this is a voice interface.
        Be friendly and helpful.
    """.trimIndent()

    suspend fun connect() {
        try {
            // Step 1: Get ephemeral token from proxy
            ephemeralToken = fetchEphemeralToken()
            Log.d(TAG, "Got ephemeral token")

            // Step 2: Connect to xAI WebSocket
            connectWebSocket()
        } catch (e: Exception) {
            Log.e(TAG, "Connection failed", e)
            onError?.invoke(e)
            throw e
        }
    }

    private suspend fun fetchEphemeralToken(): String = withContext(Dispatchers.IO) {
        val request = Request.Builder()
            .url(PROXY_URL)
            .post("{}".toRequestBody("application/json".toMediaType()))
            .addHeader("X-App-Secret", BuildConfig.APP_SECRET)
            .addHeader("Content-Type", "application/json")
            .build()

        val response = httpClient.newCall(request).execute()
        val body = response.body?.string() ?: throw Exception("Empty response from proxy")

        if (!response.isSuccessful) {
            throw Exception("Failed to get ephemeral token: $body")
        }

        val json = JSONObject(body)
        // Try different response formats
        json.optString("value").takeIf { it.isNotEmpty() }
            ?: json.optString("client_secret").takeIf { it.isNotEmpty() }
            ?: json.optJSONObject("client_secret")?.optString("value")
            ?: throw Exception("No token in response: $body")
    }

    private suspend fun connectWebSocket() = suspendCancellableCoroutine { continuation ->
        val token = ephemeralToken ?: throw Exception("No ephemeral token")

        val request = Request.Builder()
            .url(XAI_REALTIME_URL)
            .addHeader("Authorization", "Bearer $token")
            .build()

        webSocket = httpClient.newWebSocket(request, object : WebSocketListener() {
            override fun onOpen(webSocket: WebSocket, response: Response) {
                Log.d(TAG, "WebSocket connected")
                onConnected?.invoke()
                if (continuation.isActive) {
                    continuation.resume(Unit)
                }
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleMessage(text)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "WebSocket failure", t)
                val exception = Exception(t.message ?: "WebSocket failure")
                onError?.invoke(exception)
                onDisconnected?.invoke(exception)
                if (continuation.isActive) {
                    continuation.resumeWithException(exception)
                }
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.d(TAG, "WebSocket closed: $code $reason")
                onDisconnected?.invoke(null)
            }
        })

        continuation.invokeOnCancellation {
            webSocket?.cancel()
        }
    }

    private fun handleMessage(text: String) {
        try {
            val json = JSONObject(text)
            val type = json.optString("type")

            // Log all messages for debugging
            Log.d(TAG, "Received: $type - ${text.take(200)}")

            val event = when (type) {
                "session.created" -> VoiceEvent.SessionCreated
                "session.updated" -> VoiceEvent.SessionConfigured
                "input_audio_buffer.speech_started" -> VoiceEvent.UserSpeechStarted
                "input_audio_buffer.speech_stopped" -> VoiceEvent.UserSpeechStopped
                "input_audio_buffer.committed" -> {
                    Log.d(TAG, "Audio buffer committed")
                    VoiceEvent.Other
                }
                "conversation.item.created" -> {
                    Log.d(TAG, "Conversation item created")
                    VoiceEvent.Other
                }
                "response.audio.delta" -> {
                    val delta = json.optString("delta")
                    if (delta.isNotEmpty()) {
                        val audioBytes = Base64.decode(delta, Base64.DEFAULT)
                        VoiceEvent.AudioDelta(audioBytes)
                    } else {
                        VoiceEvent.Other
                    }
                }
                "response.audio_transcript.delta" -> {
                    val delta = json.optString("delta", "")
                    Log.d(TAG, "Transcript: $delta")
                    VoiceEvent.Other
                }
                "response.created", "response.output_item.added" -> {
                    val itemId = json.optJSONObject("item")?.optString("id")
                    VoiceEvent.AssistantSpeaking(itemId)
                }
                "error" -> {
                    val error = json.optJSONObject("error")
                    val message = error?.optString("message") ?: json.optString("message") ?: "Unknown error"
                    Log.e(TAG, "Error from server: $message")
                    VoiceEvent.Error(message)
                }
                else -> {
                    Log.d(TAG, "Unhandled event type: $type")
                    VoiceEvent.Other
                }
            }

            onEvent?.invoke(event)
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing message", e)
        }
    }

    fun configureSession() {
        // Match iOS xAI format exactly
        val config = JSONObject().apply {
            put("type", "session.update")
            put("session", JSONObject().apply {
                put("instructions", instructions)
                put("voice", "Leo")
                put("audio", JSONObject().apply {
                    put("input", JSONObject().apply {
                        put("format", JSONObject().apply {
                            put("type", "audio/pcm")
                            put("sample_rate", SAMPLE_RATE)
                        })
                    })
                    put("output", JSONObject().apply {
                        put("format", JSONObject().apply {
                            put("type", "audio/pcm")
                            put("sample_rate", SAMPLE_RATE)
                        })
                    })
                })
                put("turn_detection", JSONObject().apply {
                    put("type", "server_vad")
                })
            })
        }

        Log.d(TAG, "Sending session config: ${config.toString()}")
        sendMessage(config.toString())
    }

    fun sendAudioChunk(audioData: ByteArray) {
        if (audioData.isEmpty()) return

        val base64Audio = Base64.encodeToString(audioData, Base64.NO_WRAP)
        val message = JSONObject().apply {
            put("type", "input_audio_buffer.append")
            put("audio", base64Audio)
        }
        val sent = webSocket?.send(message.toString()) ?: false
        if (sent) {
            Log.v(TAG, "Sent audio chunk: ${audioData.size} bytes")
        } else {
            Log.w(TAG, "Failed to send audio chunk")
        }
    }

    fun commitAudioBuffer() {
        val message = JSONObject().apply {
            put("type", "input_audio_buffer.commit")
        }
        sendMessage(message.toString())
    }

    fun createResponse() {
        val message = JSONObject().apply {
            put("type", "response.create")
        }
        sendMessage(message.toString())
    }

    fun truncateResponse() {
        val message = JSONObject().apply {
            put("type", "response.cancel")
        }
        sendMessage(message.toString())
    }

    private fun sendMessage(text: String) {
        val sent = webSocket?.send(text) ?: false
        if (!sent) {
            Log.w(TAG, "Failed to send message")
        }
    }

    fun disconnect() {
        webSocket?.close(1000, "User disconnected")
        webSocket = null
        ephemeralToken = null
    }
}
