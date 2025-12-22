package com.allensu.grokmode.auth

import android.content.Context
import android.net.Uri
import androidx.browser.customtabs.CustomTabsIntent
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

data class AuthUiState(
    val isAuthenticated: Boolean = false,
    val userHandle: String? = null,
    val isLoading: Boolean = false,
    val error: String? = null
)

class AuthViewModel(context: Context) : ViewModel() {

    // Exposed for use by VoiceAssistantViewModel
    val authService = XAuthService(context.applicationContext)

    private val _uiState = MutableStateFlow(AuthUiState())
    val uiState: StateFlow<AuthUiState> = _uiState.asStateFlow()

    init {
        checkAuthStatus()
    }

    private fun checkAuthStatus() {
        val authState = authService.checkStatus()
        _uiState.value = AuthUiState(
            isAuthenticated = authState.isAuthenticated,
            userHandle = authState.currentUserHandle
        )
    }

    fun startLogin(context: Context) {
        _uiState.value = _uiState.value.copy(isLoading = true, error = null)

        try {
            val authUrl = authService.buildAuthUrl()
            val customTabsIntent = CustomTabsIntent.Builder()
                .setShowTitle(true)
                .build()
            customTabsIntent.launchUrl(context, Uri.parse(authUrl))
        } catch (e: Exception) {
            _uiState.value = _uiState.value.copy(
                isLoading = false,
                error = e.message ?: "Failed to start login"
            )
        }
    }

    fun handleAuthCallback(uri: Uri) {
        viewModelScope.launch {
            _uiState.value = _uiState.value.copy(isLoading = true, error = null)

            try {
                val authState = authService.handleCallback(uri)
                _uiState.value = AuthUiState(
                    isAuthenticated = authState.isAuthenticated,
                    userHandle = authState.currentUserHandle,
                    isLoading = false
                )
            } catch (e: Exception) {
                if (e is AuthError.LoginCancelled) {
                    _uiState.value = _uiState.value.copy(isLoading = false)
                    return@launch
                }
                _uiState.value = _uiState.value.copy(
                    isLoading = false,
                    error = e.message ?: "Login failed"
                )
            }
        }
    }

    fun logout() {
        authService.logout()
        _uiState.value = AuthUiState(isAuthenticated = false)
    }

    fun clearError() {
        _uiState.value = _uiState.value.copy(error = null)
    }

    class Factory(private val context: Context) : ViewModelProvider.Factory {
        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            return AuthViewModel(context) as T
        }
    }
}
