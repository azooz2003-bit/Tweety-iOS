package com.allensu.grokmode.voice

import android.content.Context
import android.util.Log
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.allensu.grokmode.auth.XAuthService
import com.allensu.grokmode.xapi.PreviewBehavior
import com.allensu.grokmode.xapi.XTool
import com.allensu.grokmode.xapi.XToolOrchestrator
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.util.UUID

private const val TAG = "VoiceAssistantVM"

/**
 * Represents a pending tool call that needs confirmation.
 */
data class PendingToolCall(
    val id: String,
    val tool: XTool,
    val arguments: Map<String, Any>,
    val previewTitle: String,
    val previewContent: String
)

data class ConversationItem(
    val id: String = UUID.randomUUID().toString(),
    val message: String,
    val timestamp: Long = System.currentTimeMillis(),
    val isToolCall: Boolean = false,
    val toolName: String? = null
)

data class VoiceUiState(
    val sessionState: VoiceSessionState = VoiceSessionState.Disconnected,
    val isSessionActive: Boolean = false,
    val conversationItems: List<ConversationItem> = emptyList(),
    val audioLevel: Float = 0f,
    val sessionDuration: Long = 0L,
    val hasMicPermission: Boolean = false,
    val pendingToolCall: PendingToolCall? = null  // For confirmation UI
)

class VoiceAssistantViewModel(
    context: Context,
    private val authService: XAuthService
) : ViewModel() {

    private val voiceService = XAIVoiceService()
    private val audioManager = AudioManager(context.applicationContext)
    private val toolOrchestrator = XToolOrchestrator(authService)

    // Queue of pending tool calls awaiting confirmation
    private val pendingToolCallQueue = mutableListOf<PendingToolCall>()

    // Authenticated user ID for tool calls
    private var authenticatedUserId: String? = null

    private val _uiState = MutableStateFlow(VoiceUiState())
    val uiState: StateFlow<VoiceUiState> = _uiState.asStateFlow()

    private var sessionTimerJob: Job? = null
    private var sessionStartTime: Long = 0L
    private var audioChunksSent: Int = 0

    init {
        checkPermissions()
        setupVoiceServiceCallbacks()
        setupAudioCallbacks()
    }

    private fun checkPermissions() {
        _uiState.value = _uiState.value.copy(
            hasMicPermission = audioManager.hasPermission()
        )
    }

    fun updatePermissionStatus() {
        checkPermissions()
    }

    private fun setupVoiceServiceCallbacks() {
        voiceService.onConnected = {
            _uiState.value = _uiState.value.copy(
                sessionState = VoiceSessionState.Connected
            )
            addSystemMessage("Connected to xAI Voice")

            // Fetch authenticated user ID and configure session with tools
            viewModelScope.launch {
                fetchAuthenticatedUserId()
                voiceService.authenticatedUserId = authenticatedUserId
                voiceService.configureSession(includeTools = true)
            }
        }

        voiceService.onEvent = { event ->
            handleVoiceEvent(event)
        }

        voiceService.onError = { error ->
            _uiState.value = _uiState.value.copy(
                sessionState = VoiceSessionState.Error(error.message ?: "Unknown error")
            )
            addSystemMessage("Error: ${error.message}")
        }

        voiceService.onDisconnected = { error ->
            Log.w(TAG, "🔴 onDisconnected callback - error: ${error?.message}")
            Log.w(TAG, "Current state: ${_uiState.value.sessionState}")
            if (_uiState.value.sessionState !is VoiceSessionState.Disconnected) {
                stopSession()
                if (error != null) {
                    addSystemMessage("Disconnected: ${error.message}")
                } else {
                    addSystemMessage("Disconnected (no error)")
                }
            }
        }
    }

    private fun setupAudioCallbacks() {
        audioManager.onAudioData = { data ->
            if (_uiState.value.sessionState.isConnected) {
                voiceService.sendAudioChunk(data)
                audioChunksSent++
                // Show first chunk to confirm audio is flowing
                if (audioChunksSent == 10) {
                    addSystemMessage("Audio streaming active (${data.size} bytes/chunk)")
                }
            }
        }

        audioManager.onAudioLevel = { level ->
            _uiState.value = _uiState.value.copy(audioLevel = level)
        }
    }

    private fun handleVoiceEvent(event: VoiceEvent) {
        when (event) {
            is VoiceEvent.SessionCreated -> {
                addSystemMessage("Session created")
            }
            is VoiceEvent.SessionConfigured -> {
                addSystemMessage("Session configured and ready")
                addSystemMessage("Speak now - audio will be sent to xAI")
                // Start recording now that session is ready
                audioManager.initPlayback()
                audioManager.startRecording(viewModelScope)
            }
            is VoiceEvent.UserSpeechStarted -> {
                _uiState.value = _uiState.value.copy(
                    sessionState = VoiceSessionState.Listening
                )
                addSystemMessage("Listening...")
                // Stop any playing audio when user starts speaking
                audioManager.stopPlayback()
                voiceService.truncateResponse()
            }
            is VoiceEvent.UserSpeechStopped -> {
                _uiState.value = _uiState.value.copy(
                    sessionState = VoiceSessionState.Connected
                )
                addSystemMessage("Processing...")
            }
            is VoiceEvent.AssistantSpeaking -> {
                _uiState.value = _uiState.value.copy(
                    sessionState = VoiceSessionState.Speaking(event.itemId)
                )
                addSystemMessage("Assistant responding...")
            }
            is VoiceEvent.AudioDelta -> {
                // Don't play if user is speaking
                val isListening = _uiState.value.sessionState.isListening
                Log.d(TAG, "🔊 AudioDelta received: ${event.audioData.size} bytes, isListening=$isListening")
                if (!isListening) {
                    audioManager.playAudio(event.audioData)
                    _uiState.value = _uiState.value.copy(
                        sessionState = VoiceSessionState.Speaking()
                    )
                } else {
                    Log.w(TAG, "⚠️ Skipping playback - user is speaking")
                }
            }
            is VoiceEvent.ToolCall -> {
                handleToolCall(event.toolCall)
            }
            is VoiceEvent.Error -> {
                _uiState.value = _uiState.value.copy(
                    sessionState = VoiceSessionState.Error(event.message)
                )
                addSystemMessage("Error: ${event.message}")
            }
            is VoiceEvent.Other -> {
                // Log but don't show in UI
            }
        }
    }

    /**
     * Fetch the authenticated user's ID for tool calls.
     */
    private suspend fun fetchAuthenticatedUserId() {
        try {
            val result = toolOrchestrator.executeTool(
                XTool.GET_AUTHENTICATED_USER,
                emptyMap()
            )
            if (result.success && result.response != null) {
                val json = JSONObject(result.response)
                val data = json.optJSONObject("data")
                authenticatedUserId = data?.optString("id")
                Log.i(TAG, "Authenticated user ID: $authenticatedUserId")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to fetch authenticated user", e)
        }
    }

    /**
     * Handle a tool call from the voice assistant.
     */
    private fun handleToolCall(toolCall: VoiceToolCall) {
        val tool = XTool.fromName(toolCall.name)
        if (tool == null) {
            Log.w(TAG, "Unknown tool: ${toolCall.name}")
            // Send error back to voice service
            voiceService.sendToolOutput(
                toolCall.id,
                """{"error": "Unknown tool: ${toolCall.name}"}"""
            )
            voiceService.createResponse()
            return
        }

        Log.i(TAG, "🔧 Handling tool call: ${tool.displayName}")
        addSystemMessage("Tool: ${tool.displayName}", isToolCall = true, toolName = tool.toolName)

        // Parse arguments
        val arguments = try {
            parseJsonToMap(toolCall.arguments)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse tool arguments", e)
            voiceService.sendToolOutput(
                toolCall.id,
                """{"error": "Invalid arguments: ${e.message}"}"""
            )
            voiceService.createResponse()
            return
        }

        // Handle voice confirmation tools specially
        when (tool) {
            XTool.CONFIRM_ACTION -> {
                val pendingId = arguments["tool_call_id"] as? String
                if (pendingId != null) {
                    confirmToolCall(pendingId)
                }
                voiceService.sendToolOutput(toolCall.id, """{"confirmed": true}""")
                voiceService.createResponse()
                return
            }
            XTool.CANCEL_ACTION -> {
                val pendingId = arguments["tool_call_id"] as? String
                if (pendingId != null) {
                    rejectToolCall(pendingId)
                }
                voiceService.sendToolOutput(toolCall.id, """{"cancelled": true}""")
                voiceService.createResponse()
                return
            }
            else -> {}
        }

        // Check if tool requires confirmation
        if (tool.previewBehavior == PreviewBehavior.REQUIRES_CONFIRMATION) {
            // Queue for confirmation
            val pending = PendingToolCall(
                id = toolCall.id,
                tool = tool,
                arguments = arguments,
                previewTitle = tool.displayName,
                previewContent = generatePreviewContent(tool, arguments)
            )
            pendingToolCallQueue.add(pending)

            // Show first pending in UI
            if (_uiState.value.pendingToolCall == null) {
                _uiState.value = _uiState.value.copy(pendingToolCall = pending)
            }

            addSystemMessage("Waiting for confirmation: ${tool.displayName}")

            // Tell assistant to ask for confirmation
            voiceService.sendToolOutput(
                toolCall.id,
                """{"status": "pending_confirmation", "message": "Waiting for user confirmation to ${tool.description.lowercase()}. Ask the user to confirm or cancel."}"""
            )
            voiceService.createResponse()
        } else {
            // Safe tool - execute immediately
            executeTool(toolCall.id, tool, arguments)
        }
    }

    /**
     * Execute a tool and send the result back to the voice service.
     */
    private fun executeTool(callId: String, tool: XTool, arguments: Map<String, Any>) {
        viewModelScope.launch {
            Log.i(TAG, "⚡ Executing tool: ${tool.toolName}")
            Log.i(TAG, "⚡ Arguments: $arguments")
            addSystemMessage("Executing: ${tool.displayName}")

            val result = toolOrchestrator.executeTool(tool, arguments, callId)

            Log.i(TAG, "Tool result: success=${result.success}, status=${result.statusCode}")

            // Send result back to voice service
            voiceService.sendToolOutput(callId, result.getOutputForVoice())

            // Request voice response
            voiceService.createResponse()

            if (result.success) {
                addSystemMessage("✓ ${tool.displayName} completed")
            } else {
                addSystemMessage("✗ ${tool.displayName} failed: ${result.error?.message}")
            }
        }
    }

    /**
     * Confirm a pending tool call (from UI button or voice).
     */
    fun confirmToolCall(callId: String) {
        val pending = pendingToolCallQueue.find { it.id == callId }
        if (pending != null) {
            pendingToolCallQueue.remove(pending)
            updatePendingToolCallUI()
            executeTool(pending.id, pending.tool, pending.arguments)
        }
    }

    /**
     * Reject a pending tool call (from UI button or voice).
     */
    fun rejectToolCall(callId: String) {
        val pending = pendingToolCallQueue.find { it.id == callId }
        if (pending != null) {
            pendingToolCallQueue.remove(pending)
            updatePendingToolCallUI()

            addSystemMessage("Cancelled: ${pending.tool.displayName}")

            // Send cancellation to voice service
            voiceService.sendToolOutput(
                callId,
                """{"status": "cancelled", "message": "User cancelled the action"}"""
            )
            voiceService.createResponse()
        }
    }

    private fun updatePendingToolCallUI() {
        _uiState.value = _uiState.value.copy(
            pendingToolCall = pendingToolCallQueue.firstOrNull()
        )
    }

    /**
     * Generate preview content for a tool call confirmation.
     */
    private fun generatePreviewContent(tool: XTool, arguments: Map<String, Any>): String {
        return when (tool) {
            XTool.CREATE_TWEET -> {
                val text = arguments["text"] as? String ?: ""
                "\"$text\""
            }
            XTool.REPLY_TO_TWEET -> {
                val text = arguments["text"] as? String ?: ""
                "Reply: \"$text\""
            }
            XTool.QUOTE_TWEET -> {
                val text = arguments["text"] as? String ?: ""
                "Quote: \"$text\""
            }
            XTool.LIKE_TWEET, XTool.UNLIKE_TWEET -> {
                val tweetId = arguments["tweet_id"] as? String ?: ""
                "Tweet ID: $tweetId"
            }
            XTool.FOLLOW_USER, XTool.UNFOLLOW_USER -> {
                val userId = arguments["target_user_id"] as? String ?: ""
                "User ID: $userId"
            }
            XTool.SEND_DM_TO_PARTICIPANT -> {
                val text = arguments["text"] as? String ?: ""
                "Message: \"$text\""
            }
            else -> arguments.toString()
        }
    }

    /**
     * Parse a JSON string to a Map.
     */
    private fun parseJsonToMap(jsonString: String): Map<String, Any> {
        if (jsonString.isBlank()) return emptyMap()

        val json = JSONObject(jsonString)
        val map = mutableMapOf<String, Any>()

        for (key in json.keys()) {
            val value = json.get(key)
            map[key] = when (value) {
                is JSONObject -> parseJsonObjectToMap(value)
                is org.json.JSONArray -> parseJsonArray(value)
                else -> value
            }
        }

        return map
    }

    private fun parseJsonObjectToMap(json: JSONObject): Map<String, Any> {
        val map = mutableMapOf<String, Any>()
        for (key in json.keys()) {
            val value = json.get(key)
            map[key] = when (value) {
                is JSONObject -> parseJsonObjectToMap(value)
                is org.json.JSONArray -> parseJsonArray(value)
                else -> value
            }
        }
        return map
    }

    private fun parseJsonArray(array: org.json.JSONArray): List<Any> {
        val list = mutableListOf<Any>()
        for (i in 0 until array.length()) {
            val value = array.get(i)
            list.add(when (value) {
                is JSONObject -> parseJsonObjectToMap(value)
                is org.json.JSONArray -> parseJsonArray(value)
                else -> value
            })
        }
        return list
    }

    fun startSession() {
        Log.i(TAG, "🚀 startSession() called")
        if (!_uiState.value.hasMicPermission) {
            Log.w(TAG, "No mic permission")
            addSystemMessage("Microphone permission required")
            return
        }

        audioChunksSent = 0
        _uiState.value = _uiState.value.copy(
            isSessionActive = true,
            sessionState = VoiceSessionState.Connecting
        )
        addSystemMessage("Connecting to xAI Voice...")
        Log.i(TAG, "State set to Connecting")

        // Start session timer
        sessionStartTime = System.currentTimeMillis()
        sessionTimerJob = viewModelScope.launch {
            while (isActive) {
                val elapsed = System.currentTimeMillis() - sessionStartTime
                _uiState.value = _uiState.value.copy(sessionDuration = elapsed)
                delay(1000)
            }
        }

        viewModelScope.launch {
            try {
                voiceService.connect()
            } catch (e: Exception) {
                _uiState.value = _uiState.value.copy(
                    sessionState = VoiceSessionState.Error(e.message ?: "Connection failed"),
                    isSessionActive = false
                )
                addSystemMessage("Connection failed: ${e.message}")
                sessionTimerJob?.cancel()
            }
        }
    }

    fun stopSession() {
        Log.i(TAG, "🛑 stopSession() called")
        Log.i(TAG, "Audio chunks sent this session: $audioChunksSent")

        sessionTimerJob?.cancel()
        sessionTimerJob = null

        audioManager.stopRecording()
        audioManager.stopPlayback()
        voiceService.disconnect()

        _uiState.value = _uiState.value.copy(
            isSessionActive = false,
            sessionState = VoiceSessionState.Disconnected,
            audioLevel = 0f,
            sessionDuration = 0L
        )
        addSystemMessage("Disconnected")
    }

    private fun addSystemMessage(
        message: String,
        isToolCall: Boolean = false,
        toolName: String? = null
    ) {
        val item = ConversationItem(
            message = message,
            isToolCall = isToolCall,
            toolName = toolName
        )
        _uiState.value = _uiState.value.copy(
            conversationItems = _uiState.value.conversationItems + item
        )
    }

    fun formatDuration(millis: Long): String {
        val totalSeconds = millis / 1000
        val minutes = totalSeconds / 60
        val seconds = totalSeconds % 60
        return String.format("%d:%02d", minutes, seconds)
    }

    override fun onCleared() {
        super.onCleared()
        stopSession()
        audioManager.release()
    }

    class Factory(
        private val context: Context,
        private val authService: XAuthService
    ) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            return VoiceAssistantViewModel(context, authService) as T
        }
    }
}
