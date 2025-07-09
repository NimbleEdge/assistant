/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.presentation.components

import dev.deliteai.assistant.presentation.ui.theme.accent
import dev.deliteai.assistant.presentation.ui.theme.accentHigh2
import dev.deliteai.assistant.presentation.viewmodels.ChatViewModel
import dev.deliteai.assistant.utils.VoiceOverlayState
import androidx.compose.animation.animateColor
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.updateTransition
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.ripple
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun VoiceOverlay(chatViewModel: ChatViewModel) {
    LaunchedEffect(Unit) {
        chatViewModel.getLLMAudioFromVoiceInput()
    }
    LaunchedEffect(Unit) {
        return@LaunchedEffect
    }
    val normalizedVolume = ((chatViewModel.volumeState.floatValue + 120) / 120).coerceIn(0f, 1f)
    val currentState = when {
        chatViewModel.isUserSpeaking.value -> VoiceOverlayState.SPEAKING
        else -> VoiceOverlayState.IDLE
    }

    val view = LocalView.current
    DisposableEffect(view) {
        view.keepScreenOn = true
        onDispose { view.keepScreenOn = false }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black.copy(alpha = 0.8f))
    ) {
        Column(
            modifier = Modifier
                .align(Alignment.Center),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            AnimatedVoiceOrb(
                voiceState = currentState,
                normalizedVolume = normalizedVolume,
                baseSize = 120.dp,
                chatViewModel
            )
            Spacer(modifier = Modifier.height(16.dp))
            AnimatedSpeechText(
                isUserSpeaking = chatViewModel.isUserSpeaking.value,
                currentText = chatViewModel.spokenText.value,
                persistedText = chatViewModel.persistedRecognizedText.value
            )
            Spacer(modifier = Modifier.height(20.dp))
            if (chatViewModel.isInterruptButtonVisible.value) {
                Text("Interrupt", modifier = Modifier.clickable {
                    chatViewModel.getLLMAudioFromVoiceInput()
                })
            }
        }
        IconButton(
            onClick = {
                chatViewModel.cancelLLMAndClearAudioQueue()
                chatViewModel.isOverlayVisible.value = false
            },
            modifier = Modifier.align(Alignment.TopEnd)
        ) {
            Icon(Icons.Default.Close, contentDescription = "Close")
        }
    }
}

object VoiceOrbAnimations {
    @Composable
    fun getOrbTransition(voiceState: VoiceOverlayState) =
        updateTransition(targetState = voiceState, label = "OrbTransition")

    @Composable
    fun getIdlePulse() = rememberInfiniteTransition().animateFloat(
        initialValue = 0.8f,
        targetValue = 0.95f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1500, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        )
    )

    @Composable
    fun getInfiniteRotation() = rememberInfiniteTransition().animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1200, easing = LinearOutSlowInEasing),
            repeatMode = RepeatMode.Restart
        )
    )
}

@Composable
fun AnimatedVoiceOrb(
    voiceState: VoiceOverlayState,
    normalizedVolume: Float,
    baseSize: Dp,
    chatViewModel: ChatViewModel
) {
    val transition = VoiceOrbAnimations.getOrbTransition(voiceState)
    val idlePulse by VoiceOrbAnimations.getIdlePulse()
    val scaleForStates by transition.animateFloat(
        transitionSpec = { tween(durationMillis = 500, easing = FastOutSlowInEasing) },
        label = "scaleAnim"
    ) { state ->
        when (state) {
            VoiceOverlayState.IDLE -> 1f
            VoiceOverlayState.SPEAKING -> 1f + normalizedVolume * 0.3f
        }
    }
    val scale = if (voiceState == VoiceOverlayState.IDLE) idlePulse else scaleForStates
    val orbAlpha by transition.animateFloat(
        transitionSpec = { tween(durationMillis = 500, easing = FastOutSlowInEasing) },
        label = "orbAlphaAnim"
    ) { state ->
        when (state) {
            VoiceOverlayState.IDLE -> 0.8f
            VoiceOverlayState.SPEAKING -> 1f
        }
    }
    val loadingArcAlpha by transition.animateFloat(
        transitionSpec = { tween(durationMillis = 500, easing = FastOutSlowInEasing) },
        label = "loadingArcAlphaAnim"
    ) { state ->
        when (state) {
            VoiceOverlayState.IDLE -> 0f
            VoiceOverlayState.SPEAKING -> 0f
        }
    }
    val startColor by transition.animateColor(
        transitionSpec = { tween(durationMillis = 500, easing = FastOutSlowInEasing) },
        label = "startColorAnim"
    ) { state ->
        when (state) {
            VoiceOverlayState.IDLE -> accent
            VoiceOverlayState.SPEAKING -> Color(0xFF972A2A)
        }
    }
    val midColor by transition.animateColor(
        transitionSpec = { tween(durationMillis = 500, easing = FastOutSlowInEasing) },
        label = "midColorAnim"
    ) { state ->
        when (state) {
            VoiceOverlayState.IDLE -> accentHigh2
            VoiceOverlayState.SPEAKING -> Color(0xFFD35B5B)
        }
    }
    val endColor by transition.animateColor(
        transitionSpec = { tween(durationMillis = 500, easing = FastOutSlowInEasing) },
        label = "endColorAnim"
    ) { state ->
        when (state) {
            VoiceOverlayState.IDLE -> Color.White
            VoiceOverlayState.SPEAKING -> Color(0xFFEBC0C0)
        }
    }
    val rotation by VoiceOrbAnimations.getInfiniteRotation()
    val colorRotation by rememberInfiniteTransition().animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 4000, easing = LinearEasing),
            repeatMode = RepeatMode.Restart
        )
    )
    val waveAlpha by rememberInfiniteTransition().animateFloat(
        initialValue = 0.3f,
        targetValue = 0.8f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 2000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        )
    )
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier
            .size(baseSize)
            .scale(scale)
    ) {
        drawOrbShadow(orbAlpha, startColor, endColor)
        drawRotatingLoadingArc(loadingArcAlpha, startColor, rotation)
        drawSphereSurface(orbAlpha, startColor, midColor, endColor, colorRotation, chatViewModel)
        drawOuterWave(waveAlpha, listOf(startColor, midColor, endColor))
    }
}

@Composable
private fun BoxScope.drawOrbShadow(alpha: Float, c1: Color, c2: Color) {
    Canvas(modifier = Modifier.fillMaxSize()) {
        if (alpha > 0f) {
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(
                        c1.copy(alpha = alpha * 0.3f),
                        c2.copy(alpha = 0f)
                    ),
                    center = center,
                    radius = size.minDimension * 1.6f
                ),
                center = center
            )
        }
    }
}

@Composable
private fun BoxScope.drawRotatingLoadingArc(alpha: Float, color: Color, rotation: Float) {
    Canvas(modifier = Modifier.fillMaxSize()) {
        if (alpha > 0f) {
            rotate(rotation) {
                drawArc(
                    color = color.copy(alpha = alpha),
                    startAngle = 0f,
                    sweepAngle = 120f,
                    useCenter = false,
                    style = Stroke(
                        width = size.minDimension / 10f,
                        cap = StrokeCap.Round
                    )
                )
            }
        }
    }
}

@Composable
private fun BoxScope.drawSphereSurface(
    alpha: Float,
    c1: Color,
    c2: Color,
    c3: Color,
    rotation: Float,
    chatViewModel: ChatViewModel
) {
    Canvas(
        modifier = Modifier
            .fillMaxSize()
            .clip(CircleShape)
            .clickable(
                onClick = { chatViewModel.shouldRestartListening() },
                interactionSource = remember { MutableInteractionSource() },
                indication = ripple(color = Color.DarkGray.copy(alpha = 0.3f))
            )
    ) {
        if (alpha > 0f) {
            rotate(rotation) {
                drawCircle(
                    brush = Brush.linearGradient(
                        colors = listOf(
                            c1.copy(alpha = alpha),
                            c2.copy(alpha = alpha),
                            c3.copy(alpha = alpha)
                        ),
                        start = Offset(0f, center.y),
                        end = Offset(size.width, center.y)
                    ),
                    radius = size.minDimension / 2f
                )
            }
        }
    }
}

@Composable
private fun BoxScope.drawOuterWave(alpha: Float, colors: List<Color>) {
    Canvas(modifier = Modifier.fillMaxSize()) {
        drawCircle(
            brush = Brush.radialGradient(
                colors = listOf(
                    colors.first().copy(alpha = alpha * 0.2f),
                    colors.last().copy(alpha = alpha * 0.1f)
                )
            ),
            radius = size.minDimension / 1.3f
        )
    }
}

@Composable
fun AnimatedSpeechText(
    isUserSpeaking: Boolean,
    currentText: String,
    persistedText: String
) {
    val textToShow = when {
        isUserSpeaking -> "Listening..."
        currentText.isNotBlank() -> currentText
        persistedText.isNotBlank() -> persistedText
        else -> "Tap to Speak! Ask me anything..."
    }
    Box(
        modifier = Modifier
            .padding(16.dp)
            .fillMaxWidth(),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = textToShow,
            textAlign = TextAlign.Center,
            color = Color.White,
            style = MaterialTheme.typography.bodyMedium.copy(
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium
            )
        )
    }
}
