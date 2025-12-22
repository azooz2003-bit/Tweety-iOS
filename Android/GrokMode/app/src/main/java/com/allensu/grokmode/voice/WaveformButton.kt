package com.allensu.grokmode.voice

import androidx.compose.animation.core.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
fun WaveformButton(
    onClick: () -> Unit,
    audioLevel: Float = 0f,
    isActive: Boolean = false,
    modifier: Modifier = Modifier
) {
    val barCount = if (isActive) 37 else 5

    Button(
        onClick = onClick,
        modifier = modifier
            .height(56.dp)
            .widthIn(min = if (isActive) 200.dp else 80.dp),
        shape = RoundedCornerShape(28.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color.Black,
            contentColor = Color.White
        )
    ) {
        WaveformBars(
            barCount = barCount,
            audioLevel = audioLevel,
            isAnimating = isActive
        )
    }
}

@Composable
private fun WaveformBars(
    barCount: Int,
    audioLevel: Float,
    isAnimating: Boolean
) {
    val infiniteTransition = rememberInfiniteTransition(label = "waveform")

    Row(
        horizontalArrangement = Arrangement.spacedBy(2.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.height(24.dp)
    ) {
        repeat(barCount) { index ->
            val phase = index.toFloat() / barCount

            // Animate height based on audio level + idle animation
            val animatedHeight by infiniteTransition.animateFloat(
                initialValue = 0.3f,
                targetValue = 1f,
                animationSpec = infiniteRepeatable(
                    animation = tween(
                        durationMillis = 600,
                        easing = FastOutSlowInEasing
                    ),
                    repeatMode = RepeatMode.Reverse,
                    initialStartOffset = StartOffset((phase * 600).toInt())
                ),
                label = "bar_$index"
            )

            val height = if (isAnimating) {
                // Combine animation with audio level
                val baseHeight = 0.3f + (audioLevel * 0.7f)
                (baseHeight * animatedHeight).coerceIn(0.2f, 1f)
            } else {
                // Static bars when not active
                0.4f + (0.3f * kotlin.math.sin(phase * kotlin.math.PI.toFloat()))
            }

            Box(
                modifier = Modifier
                    .width(3.dp)
                    .height((24.dp * height))
                    .clip(RoundedCornerShape(1.5.dp))
                    .background(Color.White)
            )
        }
    }
}

@Composable
fun ConversationBubble(
    message: String,
    isToolCall: Boolean = false,
    modifier: Modifier = Modifier
) {
    val backgroundColor = if (isToolCall) Color(0xFFE3F2FD) else Color(0xFFF5F5F5)
    val textColor = if (isToolCall) Color(0xFF1976D2) else Color(0xFF666666)

    Box(
        modifier = modifier
            .clip(RoundedCornerShape(16.dp))
            .background(backgroundColor)
            .padding(horizontal = 16.dp, vertical = 10.dp)
    ) {
        androidx.compose.material3.Text(
            text = message,
            color = textColor,
            style = androidx.compose.material3.MaterialTheme.typography.bodyMedium
        )
    }
}
