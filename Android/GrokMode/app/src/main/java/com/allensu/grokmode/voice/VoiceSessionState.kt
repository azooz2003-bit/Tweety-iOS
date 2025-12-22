package com.allensu.grokmode.voice

sealed class VoiceSessionState {
    object Disconnected : VoiceSessionState()
    object Connecting : VoiceSessionState()
    object Connected : VoiceSessionState()
    object Listening : VoiceSessionState()
    data class Speaking(val itemId: String? = null) : VoiceSessionState()
    data class Error(val message: String) : VoiceSessionState()

    val isConnected: Boolean
        get() = this is Connected || this is Listening || this is Speaking

    val isConnecting: Boolean
        get() = this is Connecting

    val isListening: Boolean
        get() = this is Listening
}
