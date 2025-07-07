/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.presentation.views

import ai.nimbleedge.nimbleedge_chatbot.R
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.accent
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.accentLow2
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.backgroundPrimary
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.backgroundSecondary
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.textSecondary
import ai.nimbleedge.nimbleedge_chatbot.utils.openUrlInBrowser
import android.app.Application
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.min

@Composable
fun IntroductionPage(modifier: Modifier = Modifier, onProceed: () -> Unit) {
    var showDialog by remember { mutableStateOf(false) }
    val application = LocalContext.current.applicationContext as Application

    if (showDialog) {
        AlertDialog(
            onDismissRequest = {},
            shape = RoundedCornerShape(16.dp),
            containerColor = backgroundSecondary,
            tonalElevation = 8.dp,
            title = {
                Text(
                    text = "Wi-Fi is recommended",
                    style = MaterialTheme.typography.titleMedium,
                    color = accent
                )
            },
            text = {
                Text(
                    text = "Downloading AI models locally. Connect to Wi-Fi for best results.",
                    style = MaterialTheme.typography.bodyMedium,
                    color = textSecondary
                )
            },
            confirmButton = {
                Button(
                    onClick = {
                        showDialog = false
                        onProceed()
                    },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp),
                    shape = RoundedCornerShape(8.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = accent)
                ) {
                    Text(
                        text = "OK",
                        style = MaterialTheme.typography.bodyLarge.copy(color = Color.White)
                    )
                }
            }
        )
    }

    Box(
        modifier = modifier
            .background(backgroundPrimary)
            .fillMaxSize()
    ) {
        BlurryShapesBackground()

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(24.dp)
        ) {
            Icon(
                painter = painterResource(id = R.drawable.ic_ne_new),
                contentDescription = null,
                modifier = Modifier.size(48.dp),
                tint = Color.White
            )

            Box(
                modifier = Modifier
                    .fillMaxSize()
            ) {
                Column(Modifier.align(Alignment.BottomCenter)) {
                    Box(Modifier.width(340.dp)) {
                        Text(
                            buildAnnotatedString {
                                append("Hi! I'm NimbleEdge ")
                                withStyle(SpanStyle(color = accent)) {
                                    append("AI. ")
                                }
                                append("Your privacy aware personal assistant.")
                            },
                            style = MaterialTheme.typography.titleLarge.copy(color = Color.White)
                        )
                    }

                    Spacer(Modifier.height(16.dp))
                    Text(
                        buildAnnotatedString {
                            append("All your interactions are completely private and powered by Local ")
                            withStyle(
                                SpanStyle(
                                    color = accent,
                                    fontWeight = FontWeight.SemiBold
                                )
                            ) {
                                append("AI Models")
                            }
                        },
                        style = MaterialTheme.typography.bodyMedium.copy(color = textSecondary)
                    )
                    Spacer(Modifier.height(64.dp))
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.clickable { showDialog = true }
                    ) {
                        Text(
                            "Let's get started",
                            style = MaterialTheme.typography.bodyLarge.copy(color = accent)
                        )
                        Icon(
                            Icons.AutoMirrored.Filled.KeyboardArrowRight,
                            contentDescription = null,
                            tint = accent
                        )
                    }
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = buildAnnotatedString {
                            append("By proceeding, you agree to our ")
                            withStyle(
                                style = SpanStyle(
                                    color = Color.White.copy(alpha = 0.8f),
                                    fontWeight = FontWeight.SemiBold
                                )
                            ) {
                                append("Privacy Policy")
                            }
                            append(".")
                        },
                        modifier = Modifier.align(Alignment.Start).clickable {
                            openUrlInBrowser(application, "https://www.nimbleedge.com/nimbleedge-ai-privacy-policy")
                        },
                        style = MaterialTheme.typography.bodySmall.copy(color = Color.Gray),
                    )
                }
            }
        }

        if (showDialog) {
            Box(
                Modifier
                    .fillMaxSize()
                    .background(Color.Black.copy(alpha = 0.8f))
            )
        }
    }
}

@Composable
fun BlurryShapesBackground() {
    val infiniteTransition = rememberInfiniteTransition()
    val offsetX1 by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 200f,
        animationSpec = infiniteRepeatable(
            animation = tween(5000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        )
    )
    val offsetY1 by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = 100f,
        animationSpec = infiniteRepeatable(
            animation = tween(7000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        )
    )

    val offsetX2 by infiniteTransition.animateFloat(
        initialValue = 100f,
        targetValue = 300f,
        animationSpec = infiniteRepeatable(
            animation = tween(6000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        )
    )
    val offsetY2 by infiniteTransition.animateFloat(
        initialValue = 200f,
        targetValue = 50f,
        animationSpec = infiniteRepeatable(
            animation = tween(8000, easing = LinearEasing),
            repeatMode = RepeatMode.Reverse
        )
    )

    val shapeColors = listOf(
        Color(0xFF313A61),
        Color(0xFF972A2A),
        Color(0xFF0DB8C6),
        Color(0xFFEABB0F),
        Color(0xFFF3EEE8)
    )

    androidx.compose.foundation.Canvas(
        modifier = Modifier
            .fillMaxSize()
            .blur(radius = 60.dp)
    ) {
        val w = size.width
        val h = size.height
        val minDim = min(w, h)
        val shift = 80f

        drawCircle(
            color = shapeColors[0].copy(alpha = 0.7f),
            center = center.copy(x = w / 4 + offsetX1, y = h / 3 + offsetY1 - shift),
            radius = minDim / 6f
        )
        drawCircle(
            color = shapeColors[2].copy(alpha = 0.5f),
            center = center.copy(x = w * 3 / 4 + offsetX2, y = h * 2 / 3 + offsetY2 - shift),
            radius = minDim / 8f
        )
        drawCircle(
            color = shapeColors[3].copy(alpha = 0.4f),
            center = center.copy(y = center.y - shift),
            radius = minDim / 5f
        )
        drawCircle(
            color = shapeColors[1].copy(alpha = 0.3f),
            center = center.copy(x = w / 2 - offsetX2 / 2, y = h / 2 + offsetY1 / 2 - shift),
            radius = minDim / 7f
        )
        drawCircle(
            color = shapeColors[4].copy(alpha = 0.2f),
            center = center.copy(x = w / 2 + offsetX1 / 2, y = h / 2 - offsetY2 / 2 - shift),
            radius = minDim / 3.5f
        )
    }
}
