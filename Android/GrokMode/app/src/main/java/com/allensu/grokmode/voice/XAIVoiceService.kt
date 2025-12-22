package com.allensu.grokmode.voice

import android.util.Base64
import android.util.Log
import com.allensu.grokmode.BuildConfig
import com.allensu.grokmode.xapi.XTool
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

/**
 * Represents a tool call from the voice assistant.
 */
data class VoiceToolCall(
    val id: String,
    val name: String,
    val arguments: String  // JSON string of arguments
)

sealed class VoiceEvent {
    object SessionCreated : VoiceEvent()
    object SessionConfigured : VoiceEvent()
    object UserSpeechStarted : VoiceEvent()
    object UserSpeechStopped : VoiceEvent()
    data class AssistantSpeaking(val itemId: String?) : VoiceEvent()
    data class AudioDelta(val audioData: ByteArray) : VoiceEvent()
    data class ToolCall(val toolCall: VoiceToolCall) : VoiceEvent()
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

    // User ID for authenticated user (set before session config)
    var authenticatedUserId: String? = null

    private fun buildInstructions(): String {
        val userIdInstruction = authenticatedUserId?.let {
            "\n\nIMPORTANT: The authenticated user's ID is '$it'. Use this ID for any tool calls that require the authenticated user's ID (such as liking tweets, following users, posting tweets, etc.)."
        } ?: ""

        return """
            You are a helpful voice assistant for GrokMode, a voice-powered app for X (Twitter).
            Keep responses concise and conversational since this is a voice interface.
            Be friendly and helpful.

            You have access to various X (Twitter) API tools to help users interact with the platform.
            When a user asks you to perform an action (like posting a tweet, liking, following, etc.),
            use the appropriate tool. For read operations (searching, getting tweets, etc.), execute immediately.
            For write operations (posting, liking, following, etc.), the user may need to confirm the action.

            When calling tools that require the authenticated user's ID, use the ID provided in this context.$userIdInstruction
        """.trimIndent()
    }

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
                Log.i(TAG, "✅ WebSocket CONNECTED - Response: ${response.code}")
                audioChunkCount = 0
                totalBytesSent = 0
                onConnected?.invoke()
                if (continuation.isActive) {
                    continuation.resume(Unit)
                }
            }

            override fun onMessage(webSocket: WebSocket, text: String) {
                handleMessage(text)
            }

            override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
                Log.e(TAG, "❌ WebSocket FAILURE: ${t.message}", t)
                Log.e(TAG, "Response: ${response?.code} - ${response?.message}")
                val exception = Exception(t.message ?: "WebSocket failure")
                onError?.invoke(exception)
                onDisconnected?.invoke(exception)
                if (continuation.isActive) {
                    continuation.resumeWithException(exception)
                }
            }

            override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
                Log.w(TAG, "⚠️ WebSocket CLOSING: code=$code reason=$reason")
            }

            override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
                Log.w(TAG, "🔴 WebSocket CLOSED: code=$code reason=$reason")
                Log.i(TAG, "Session stats: sent $audioChunkCount chunks, $totalBytesSent bytes")
                onDisconnected?.invoke(null)
            }
        })

        continuation.invokeOnCancellation {
            webSocket?.cancel()
        }
    }

    private var audioChunkCount = 0
    private var totalBytesSent = 0L

    private fun handleMessage(text: String) {
        try {
            val json = JSONObject(text)
            val type = json.optString("type")

            // Log ALL messages verbosely for debugging
            Log.i(TAG, "━━━ RECEIVED EVENT: $type ━━━")
            Log.d(TAG, "Full message: ${text.take(500)}")

            val event = when (type) {
                "ping" -> {
                    // Respond to ping with pong to keep connection alive
                    val eventId = json.optString("event_id")
                    Log.d(TAG, "🏓 Ping received, sending pong")
                    val pong = JSONObject().apply {
                        put("type", "pong")
                        put("event_id", eventId)
                    }
                    sendMessage(pong.toString())
                    VoiceEvent.Other
                }
                "session.created" -> {
                    Log.i(TAG, "🟢 Session CREATED")
                    VoiceEvent.SessionCreated
                }
                "session.updated" -> {
                    Log.i(TAG, "🟢 Session CONFIGURED - ready for audio!")
                    VoiceEvent.SessionConfigured
                }
                "input_audio_buffer.speech_started" -> {
                    Log.i(TAG, "🎤 VAD: Speech STARTED - server detected voice!")
                    VoiceEvent.UserSpeechStarted
                }
                "input_audio_buffer.speech_stopped" -> {
                    Log.i(TAG, "🎤 VAD: Speech STOPPED - processing...")
                    VoiceEvent.UserSpeechStopped
                }
                "input_audio_buffer.committed" -> {
                    Log.i(TAG, "📦 Audio buffer COMMITTED")
                    VoiceEvent.Other
                }
                "conversation.item.created" -> {
                    val role = json.optJSONObject("item")?.optString("role", "unknown")
                    Log.i(TAG, "💬 Conversation item created (role: $role)")
                    VoiceEvent.Other
                }
                "response.created" -> {
                    Log.i(TAG, "🤖 Response CREATED - assistant is preparing response")
                    val itemId = json.optJSONObject("item")?.optString("id")
                    VoiceEvent.AssistantSpeaking(itemId)
                }
                "response.output_item.added" -> {
                    Log.i(TAG, "🤖 Response output item added")
                    val itemId = json.optJSONObject("item")?.optString("id")
                    VoiceEvent.AssistantSpeaking(itemId)
                }
                "response.audio.delta" -> {
                    val delta = json.optString("delta")
                    if (delta.isNotEmpty()) {
                        val audioBytes = Base64.decode(delta, Base64.DEFAULT)
                        Log.d(TAG, "🔊 Audio delta received: ${audioBytes.size} bytes")
                        VoiceEvent.AudioDelta(audioBytes)
                    } else {
                        VoiceEvent.Other
                    }
                }
                "response.output_audio.delta" -> {
                    // xAI uses this event type for audio deltas
                    val delta = json.optString("delta")
                    if (delta.isNotEmpty()) {
                        val audioBytes = Base64.decode(delta, Base64.DEFAULT)
                        Log.d(TAG, "🔊 Output audio delta: ${audioBytes.size} bytes")
                        VoiceEvent.AudioDelta(audioBytes)
                    } else {
                        VoiceEvent.Other
                    }
                }
                "response.audio_transcript.delta", "response.output_audio_transcript.delta" -> {
                    val delta = json.optString("delta", "")
                    Log.i(TAG, "📝 Transcript: $delta")
                    VoiceEvent.Other
                }
                "response.done" -> {
                    Log.i(TAG, "✅ Response DONE")
                    VoiceEvent.Other
                }
                "response.function_call_arguments.done" -> {
                    // Tool call from the assistant
                    val callId = json.optString("call_id")
                    val name = json.optString("name")
                    val arguments = json.optString("arguments")
                    Log.i(TAG, "🔧 Tool call: $name (id: $callId)")
                    Log.d(TAG, "Arguments: $arguments")
                    if (callId.isNotEmpty() && name.isNotEmpty()) {
                        VoiceEvent.ToolCall(VoiceToolCall(
                            id = callId,
                            name = name,
                            arguments = arguments
                        ))
                    } else {
                        Log.w(TAG, "Invalid tool call - missing id or name")
                        VoiceEvent.Other
                    }
                }
                "error" -> {
                    val error = json.optJSONObject("error")
                    val message = error?.optString("message") ?: json.optString("message") ?: "Unknown error"
                    val code = error?.optString("code") ?: "no_code"
                    Log.e(TAG, "❌ SERVER ERROR: [$code] $message")
                    VoiceEvent.Error(message)
                }
                else -> {
                    Log.w(TAG, "⚪ Unhandled event: $type")
                    VoiceEvent.Other
                }
            }

            onEvent?.invoke(event)
        } catch (e: Exception) {
            Log.e(TAG, "Error parsing message", e)
        }
    }

    fun configureSession(includeTools: Boolean = true) {
        // Build tool definitions
        val toolsArray = if (includeTools) {
            JSONArray().apply {
                for (tool in XTool.supportedTools) {
                    put(JSONObject().apply {
                        put("type", "function")
                        put("name", tool.toolName)
                        put("description", tool.description)
                        put("parameters", tool.getJsonSchema())
                    })
                }
                // Also add built-in xAI tools
                put(JSONObject().apply { put("type", "x_search") })
                put(JSONObject().apply { put("type", "web_search") })
            }
        } else null

        // Match iOS xAI format exactly
        val config = JSONObject().apply {
            put("type", "session.update")
            put("session", JSONObject().apply {
                put("instructions", buildInstructions())
                put("voice", "Leo")
                put("audio", JSONObject().apply {
                    put("input", JSONObject().apply {
                        put("format", JSONObject().apply {
                            put("type", "audio/pcm")
                            put("rate", SAMPLE_RATE)  // iOS uses "rate" not "sample_rate"
                        })
                    })
                    put("output", JSONObject().apply {
                        put("format", JSONObject().apply {
                            put("type", "audio/pcm")
                            put("rate", SAMPLE_RATE)  // iOS uses "rate" not "sample_rate"
                        })
                    })
                })
                put("turn_detection", JSONObject().apply {  // xAI API uses snake_case
                    put("type", "server_vad")
                    put("threshold", 0.5)  // Speech detection threshold (0-1)
                    put("silence_duration_ms", 500)  // How long silence before end of turn
                    put("prefix_padding_ms", 300)  // Audio to include before speech
                })
                toolsArray?.let { put("tools", it) }
                if (includeTools) {
                    put("tool_choice", "auto")  // Let the model decide when to use tools
                }
            })
        }

        Log.d(TAG, "Sending session config with ${toolsArray?.length() ?: 0} tools")
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
            audioChunkCount++
            totalBytesSent += audioData.size
            // Log every 10 chunks to avoid spam
            if (audioChunkCount % 10 == 0) {
                Log.i(TAG, "📤 Audio stats: $audioChunkCount chunks sent, $totalBytesSent total bytes")
            }
        } else {
            Log.e(TAG, "❌ Failed to send audio chunk - WebSocket state: ${webSocket != null}")
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

    /**
     * Send a tool output back to the voice service after executing a tool call.
     * @param callId The ID of the original tool call
     * @param output The JSON output from the tool execution
     */
    fun sendToolOutput(callId: String, output: String) {
        // First, create a conversation item with the function output
        val itemMessage = JSONObject().apply {
            put("type", "conversation.item.create")
            put("item", JSONObject().apply {
                put("type", "function_call_output")
                put("call_id", callId)
                put("output", output)
            })
        }
        Log.d(TAG, "📤 Sending tool output for call $callId")
        sendMessage(itemMessage.toString())
    }

    fun truncateResponse() {
        // xAI doesn't support truncation API - no-op (matches iOS behavior)
        Log.d(TAG, "truncateResponse() called - no-op for xAI")
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
