/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.presentation.views

import dev.deliteai.assistant.presentation.ui.theme.accentHigh1
import dev.deliteai.assistant.presentation.ui.theme.backgroundPrimary
import dev.deliteai.assistant.presentation.ui.theme.backgroundSecondary
import android.util.Log
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlin.math.abs

@Composable
fun InitStatusView(
    message: String,
    percentageCompleted: Float
) {
    val progressAnim = remember { Animatable(0f) }
    val eventChannel = remember { Channel<Float>(Channel.UNLIMITED) }
    var lastProgress by remember { mutableStateOf(0f) }
    var inReset by remember { mutableStateOf(false) }

    fun restrictPercentageDomain(value: Float) = (value / 100f).coerceIn(0f, 1f)

    LaunchedEffect(percentageCompleted) {
        val currentProgress = restrictPercentageDomain(percentageCompleted)
        if (currentProgress >= 1f || abs(currentProgress - lastProgress) > 0.02) {
            // discard any queued updates and jump straight to current
            while (eventChannel.tryReceive().isSuccess) {
            }
            progressAnim.snapTo(currentProgress)
            lastProgress = currentProgress
        } else {
            eventChannel.send(currentProgress)
        }
    }

    LaunchedEffect(Unit) {
        for (target in eventChannel) {
            if (!inReset && target < lastProgress) {
                inReset = true

                progressAnim.animateTo(1f, tween(200, easing = FastOutSlowInEasing))
                progressAnim.snapTo(0f)
                progressAnim.animateTo(target, tween(100, easing = FastOutSlowInEasing))
                lastProgress = target
                inReset = false

                val buffer = mutableListOf<Float>()
                while (true) {
                    val next = eventChannel.tryReceive().getOrNull() ?: break
                    buffer += next
                }
                for (queued in buffer) {
                    progressAnim.animateTo(queued, tween(100, easing = FastOutSlowInEasing))
                    lastProgress = queued
                    delay(20)
                }
            } else if (!inReset) {
                val spec = tween<Float>(500, easing = FastOutSlowInEasing)
                progressAnim.animateTo(target, spec)
                lastProgress = target
            }
        }
    }

    val infiniteTransition = rememberInfiniteTransition()
    val blinkAlpha by infiniteTransition.animateFloat(
        initialValue = 1f,
        targetValue = 0.8f,
        animationSpec = infiniteRepeatable(
            animation = tween(800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        )
    )

    Box(
        Modifier
            .fillMaxSize()
            .background(backgroundPrimary)
            .padding(24.dp)
    ) {
        Column(
            modifier = Modifier.align(Alignment.Center),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                "Please wait",
                style = MaterialTheme.typography.bodyLarge.copy(
                    color = Color.White, fontWeight = FontWeight.Medium
                )
            )
            Spacer(Modifier.height(4.dp))
            Text(
                "I'm taking care of a few things…",
                style = MaterialTheme.typography.bodyMedium.copy(color = Color.Gray)
            )
            Spacer(Modifier.height(16.dp))

            Box(
                Modifier
                    .alpha(blinkAlpha)
                    .clip(RoundedCornerShape(8.dp))
            ) {
                LinearProgressIndicator(
                    progress = { progressAnim.value },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(20.dp),
                    color = accentHigh1,
                    trackColor = backgroundSecondary,
                    strokeCap = StrokeCap.Butt,
                    gapSize = 0.dp,
                    drawStopIndicator = {}
                )
                Text(
                    percentageCompleted.toInt().toString()+"%",
                    Modifier.align(Alignment.Center),
                    style = MaterialTheme.typography.bodySmall.copy(
                        fontWeight = FontWeight.Bold,
                        color = Color.White.copy(alpha = 0.8f)
                    ),
                    maxLines = 1,
                    overflow = TextOverflow.Clip,
                    textAlign = TextAlign.Center
                )
            }

            Spacer(Modifier.height(8.dp))

            Text(
                text = message,
                Modifier.alpha(blinkAlpha),
                style = MaterialTheme.typography.bodySmall.copy(color = Color.Gray),
                textAlign = TextAlign.Center
            )
        }
    }
}
