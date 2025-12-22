package com.allensu.grokmode.voice

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun VoiceAssistantScreen(
    onNavigateToSettings: () -> Unit = {},
    onLogout: () -> Unit = {},
    viewModel: VoiceAssistantViewModel = viewModel(
        factory = VoiceAssistantViewModel.Factory(LocalContext.current)
    )
) {
    val uiState by viewModel.uiState.collectAsState()
    val listState = rememberLazyListState()
    var showMenu by remember { mutableStateOf(false) }

    // Permission launcher
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission()
    ) { granted ->
        viewModel.updatePermissionStatus()
        if (granted && !uiState.isSessionActive) {
            viewModel.startSession()
        }
    }

    // Auto-scroll to bottom when new items added
    LaunchedEffect(uiState.conversationItems.size) {
        if (uiState.conversationItems.isNotEmpty()) {
            listState.animateScrollToItem(uiState.conversationItems.size - 1)
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            text = "Voice Service",
                            fontSize = 12.sp,
                            color = Color.Gray
                        )
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.Center
                        ) {
                            Text(
                                text = "xAI",
                                fontSize = 16.sp,
                                fontWeight = FontWeight.Bold
                            )
                            Spacer(Modifier.width(8.dp))
                            ConnectionIndicator(state = uiState.sessionState)
                        }
                    }
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateToSettings) {
                        Icon(Icons.Default.Settings, contentDescription = "Settings")
                    }
                },
                actions = {
                    Box {
                        IconButton(onClick = { showMenu = true }) {
                            Icon(Icons.Default.MoreVert, contentDescription = "Menu")
                        }
                        DropdownMenu(
                            expanded = showMenu,
                            onDismissRequest = { showMenu = false }
                        ) {
                            DropdownMenuItem(
                                text = { Text("Logout") },
                                onClick = {
                                    showMenu = false
                                    onLogout()
                                }
                            )
                        }
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.White
                )
            )
        },
        bottomBar = {
            BottomBar(
                isSessionActive = uiState.isSessionActive,
                audioLevel = uiState.audioLevel,
                sessionDuration = uiState.sessionDuration,
                onStartSession = {
                    if (uiState.hasMicPermission) {
                        viewModel.startSession()
                    } else {
                        permissionLauncher.launch(Manifest.permission.RECORD_AUDIO)
                    }
                },
                onStopSession = { viewModel.stopSession() },
                formatDuration = { viewModel.formatDuration(it) }
            )
        },
        containerColor = Color.White
    ) { paddingValues ->
        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(horizontal = 16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            contentPadding = PaddingValues(vertical = 16.dp)
        ) {
            items(uiState.conversationItems, key = { it.id }) { item ->
                ConversationBubble(message = item.message)
            }
        }
    }
}

@Composable
private fun ConnectionIndicator(state: VoiceSessionState) {
    when (state) {
        is VoiceSessionState.Connected,
        is VoiceSessionState.Listening,
        is VoiceSessionState.Speaking -> {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .background(Color.Green, shape = androidx.compose.foundation.shape.CircleShape)
            )
        }
        is VoiceSessionState.Connecting -> {
            CircularProgressIndicator(
                modifier = Modifier.size(12.dp),
                strokeWidth = 2.dp
            )
        }
        else -> {
            // No indicator when disconnected
        }
    }
}

@Composable
private fun BottomBar(
    isSessionActive: Boolean,
    audioLevel: Float,
    sessionDuration: Long,
    onStartSession: () -> Unit,
    onStopSession: () -> Unit,
    formatDuration: (Long) -> String
) {
    Surface(
        color = Color.White,
        shadowElevation = 8.dp
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            if (isSessionActive) {
                // Timer
                Text(
                    text = formatDuration(sessionDuration),
                    fontSize = 14.sp,
                    color = Color.Gray,
                    modifier = Modifier.padding(end = 16.dp)
                )

                // Active waveform
                WaveformButton(
                    onClick = { },
                    audioLevel = audioLevel,
                    isActive = true
                )

                Spacer(Modifier.width(16.dp))

                // Stop button
                Button(
                    onClick = onStopSession,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = Color.Red.copy(alpha = 0.1f),
                        contentColor = Color.Red
                    )
                ) {
                    Text("Stop")
                }
            } else {
                // Start button
                WaveformButton(
                    onClick = onStartSession,
                    isActive = false
                )
            }
        }
    }
}
