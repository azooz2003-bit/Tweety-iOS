package com.allensu.grokmode

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import com.allensu.grokmode.auth.AuthViewModel
import com.allensu.grokmode.ui.theme.GrokModeTheme
import com.allensu.grokmode.ui.theme.LoginScreen
import com.allensu.grokmode.voice.VoiceAssistantScreen

class MainActivity : ComponentActivity() {

    private val authViewModel: AuthViewModel by viewModels {
        AuthViewModel.Factory(applicationContext)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        // Handle OAuth callback if app was launched via deep link
        handleIntent(intent)

        setContent {
            GrokModeTheme {
                val authState by authViewModel.uiState.collectAsState()

                if (authState.isAuthenticated) {
                    VoiceAssistantScreen(
                        authService = authViewModel.authService,
                        onLogout = { authViewModel.logout() }
                    )
                } else {
                    LoginScreen(
                        isLoading = authState.isLoading,
                        error = authState.error,
                        onSignInWithX = { authViewModel.startLogin(this) },
                        onDismissError = { authViewModel.clearError() }
                    )
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        val uri = intent?.data ?: return

        // Check if this is our OAuth callback
        if (uri.scheme == "grokmode") {
            authViewModel.handleAuthCallback(uri)
        }
    }
}
