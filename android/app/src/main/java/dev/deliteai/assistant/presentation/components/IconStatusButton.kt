/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.presentation.components

import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.accentLow1
import androidx.compose.animation.Crossfade
import androidx.compose.animation.animateContentSize
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowRight
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp

@Composable
fun IconStatusButton(
    status: IconStatusButtonStates,
    onClick: () -> Unit
) {
    Box(
        modifier = Modifier
            .size(48.dp)
            .clickable(enabled = status == IconStatusButtonStates.IDLE) {
                onClick()
            }
            .background(accentLow1, shape = RoundedCornerShape(8.dp))
            .animateContentSize(animationSpec = tween(durationMillis = 300))
    ) {
        Crossfade(
            targetState = status,
            animationSpec = tween(durationMillis = 300),
            label = "IconStateCrossfade",
            modifier = Modifier.align(Alignment.Center)
        ) { current ->
            when (current) {
                IconStatusButtonStates.IDLE -> {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.KeyboardArrowRight,
                        contentDescription = "Go",
                        modifier = Modifier.align(Alignment.Center)
                    )
                }

                IconStatusButtonStates.LOADING -> {
                    CircularProgressIndicator(
                        modifier = Modifier
                            .size(24.dp)
                            .align(Alignment.Center),
                        strokeWidth = 2.dp,
                        color = Color.White
                    )
                }

                IconStatusButtonStates.SUCCESS -> {
                    Icon(
                        imageVector = Icons.Default.CheckCircle,
                        contentDescription = "Success",
                        modifier = Modifier.align(Alignment.Center)
                    )
                }
            }
        }
    }
}

enum class IconStatusButtonStates {
    IDLE,
    LOADING,
    SUCCESS
}
