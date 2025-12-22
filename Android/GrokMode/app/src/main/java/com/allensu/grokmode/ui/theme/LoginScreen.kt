package com.allensu.grokmode.ui.theme

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun LoginScreen(
    isLoading: Boolean = false,
    error: String? = null,
    onSignInWithX: () -> Unit,
    onDismissError: () -> Unit = {}
) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.White)
            .padding(24.dp)
    ) {
        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(Modifier.height(120.dp))

            // Circle icon
            Box(
                modifier = Modifier
                    .size(72.dp)
                    .clip(CircleShape)
                    .background(Color.Black),
                contentAlignment = Alignment.Center
            ) {
                // Replace with your waveform icon
                // Put a drawable in res/drawable/waveform.png and use it here:
                // Image(painterResource(R.drawable.waveform), contentDescription = null)
                Text("♪", color = Color.White, fontSize = 26.sp)
            }

            Spacer(Modifier.height(18.dp))

            Text(
                text = "GrokMode",
                fontSize = 34.sp,
                fontWeight = FontWeight.Bold,
                color = Color.Black
            )

            Spacer(Modifier.height(6.dp))

            Text(
                text = "Voice Agent for X",
                fontSize = 14.sp,
                color = Color(0xFF8A8A8A)
            )

            Spacer(Modifier.height(40.dp))

            // Error message
            if (error != null) {
                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 16.dp),
                    colors = CardDefaults.cardColors(containerColor = Color(0xFFFFEBEE))
                ) {
                    Row(
                        modifier = Modifier.padding(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = error,
                            color = Color(0xFFC62828),
                            fontSize = 14.sp,
                            modifier = Modifier.weight(1f)
                        )
                        TextButton(onClick = onDismissError) {
                            Text("Dismiss", color = Color(0xFFC62828))
                        }
                    }
                }
            }

            Button(
                onClick = onSignInWithX,
                enabled = !isLoading,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(54.dp),
                shape = RoundedCornerShape(14.dp),
                colors = ButtonDefaults.buttonColors(
                    containerColor = Color.Black,
                    contentColor = Color.White
                )
            ) {
                if (isLoading) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(24.dp),
                        color = Color.White,
                        strokeWidth = 2.dp
                    )
                    Spacer(Modifier.width(10.dp))
                    Text("Signing in...", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                } else {
                    Text("𝕏", fontSize = 18.sp)
                    Spacer(Modifier.width(10.dp))
                    Text("Sign in with X", fontSize = 16.sp, fontWeight = FontWeight.SemiBold)
                }
            }

            Spacer(Modifier.weight(1f))

            Text(
                text = "Powered by xAI",
                fontSize = 12.sp,
                color = Color(0xFF9A9A9A)
            )
        }
    }
}
