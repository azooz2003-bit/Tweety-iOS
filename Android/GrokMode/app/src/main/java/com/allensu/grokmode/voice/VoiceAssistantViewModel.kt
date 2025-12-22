package com.allensu.grokmode.voice

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import java.util.UUID

data class ConversationItem(
    val id: String = UUID.randomUUID().toString(),
    val message: String,
    val timestamp: Long = System.currentTimeMillis()
)

data class VoiceUiState(
    val sessionState: VoiceSessionState = VoiceSessionState.Disconnected,
    val isSessionActive: Boolean = false,
    val conversationItems: List<ConversationItem> = emptyList(),
    val audioLevel: Float = 0f,
    val sessionDuration: Long = 0L,
    val hasMicPermission: Boolean = false
)

class VoiceAssistantViewModel(context: Context) : ViewModel() {

    private val voiceService = XAIVoiceService()
    private val audioManager = AudioManager(context.applicationContext)

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

            // Configure session after connection
            voiceService.configureSession()
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
            if (_uiState.value.sessionState !is VoiceSessionState.Disconnected) {
                stopSession()
                if (error != null) {
                    addSystemMessage("Disconnected: ${error.message}")
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
                if (!_uiState.value.sessionState.isListening) {
                    audioManager.playAudio(event.audioData)
                    _uiState.value = _uiState.value.copy(
                        sessionState = VoiceSessionState.Speaking()
                    )
                }
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

    fun startSession() {
        if (!_uiState.value.hasMicPermission) {
            addSystemMessage("Microphone permission required")
            return
        }

        audioChunksSent = 0
        _uiState.value = _uiState.value.copy(
            isSessionActive = true,
            sessionState = VoiceSessionState.Connecting
        )
        addSystemMessage("Connecting to xAI Voice...")

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

    private fun addSystemMessage(message: String) {
        val item = ConversationItem(message = message)
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

    class Factory(private val context: Context) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            return VoiceAssistantViewModel(context) as T
        }
    }
}
