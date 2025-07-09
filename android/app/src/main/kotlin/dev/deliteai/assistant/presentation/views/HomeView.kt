/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.presentation.views

import dev.deliteai.assistant.R
import dev.deliteai.assistant.presentation.ui.theme.accent
import dev.deliteai.assistant.presentation.ui.theme.accentHigh1
import dev.deliteai.assistant.presentation.ui.theme.accentLow1
import dev.deliteai.assistant.presentation.ui.theme.accentLow2
import dev.deliteai.assistant.presentation.ui.theme.backgroundPrimary
import dev.deliteai.assistant.presentation.viewmodels.HistoryViewModel
import dev.deliteai.assistant.presentation.viewmodels.MainViewModel
import dev.deliteai.assistant.utils.Constants
import dev.deliteai.assistant.utils.GlobalState
import dev.deliteai.assistant.utils.openUrlInBrowser
import android.app.Application
import androidx.compose.animation.animateColor
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.History
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.airbnb.lottie.compose.LottieAnimation
import com.airbnb.lottie.compose.LottieCompositionSpec
import com.airbnb.lottie.compose.LottieConstants
import com.airbnb.lottie.compose.animateLottieCompositionAsState
import com.airbnb.lottie.compose.rememberLottieComposition
import compose.icons.FeatherIcons
import compose.icons.feathericons.MessageCircle

@Composable
fun HomeView(mainViewModel: MainViewModel, historyViewModel: HistoryViewModel) {
    val application = LocalContext.current.applicationContext as Application

    Box(modifier = Modifier.fillMaxSize()) {
        Column(
            modifier = Modifier
                .background(backgroundPrimary)
                .fillMaxSize()
                .windowInsetsPadding(WindowInsets.systemBars),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Column(
                Modifier
                    .background(backgroundPrimary)
                    .padding(vertical = 32.dp, horizontal = 24.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Image(
                        painterResource(R.drawable.ic_ne_new),
                        contentDescription = null,
                        modifier = Modifier.height(24.dp)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        "NimbleEdge ",
                        style = MaterialTheme.typography.titleLarge.copy(fontSize = 20.sp)
                    )
                    Text(
                        "AI",
                        style = MaterialTheme.typography.titleLarge.copy(
                            fontSize = 20.sp,
                            color = accent
                        )
                    )
                }
                Spacer(Modifier.height(4.dp))
                Text(
                    "How can I help you today?",
                    style = MaterialTheme.typography.bodyMedium.copy(color = Color.Gray)
                )
            }
            Spacer(Modifier.height(40.dp))
            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
                contentAlignment = Alignment.Center
            ) {
                AiEntity()
            }
            Spacer(Modifier.height(80.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.SpaceAround
            ) {
                ActionIcons(
                    Icons.Rounded.History,
                    false,
                    Constants.VIEWS.HISTORY_VIEW.str,
                    mainViewModel,
                    historyViewModel
                )
                Spacer(Modifier.width(16.dp))
                Box(contentAlignment = Alignment.Center) {
                    ActionIcons(
                        FeatherIcons.MessageCircle,
                        true,
                        Constants.VIEWS.CHAT_VIEW.str,
                        mainViewModel,
                        historyViewModel
                    )

                }
                Spacer(Modifier.width(16.dp))
                ActionIcons(
                    Icons.Rounded.GraphicEq,
                    false,
                    Constants.VIEWS.VOICE_VIEW.str,
                    mainViewModel,
                    historyViewModel
                )
            }
            Spacer(Modifier.height(32.dp))
            Row(modifier = Modifier.clickable {
                openUrlInBrowser(application, "https://www.nimbleedge.com/contact")
            }) {
                Text(
                    "Have a suggestion? Feel free to",
                    style = MaterialTheme.typography.bodySmall.copy(color = Color.Gray),
                )
                Text(
                    " get in touch!",
                    style = MaterialTheme.typography.bodySmall.copy(color = accent)
                )
            }
        }
    }
}

@Composable
fun AiEntity() {
    val composition by rememberLottieComposition(LottieCompositionSpec.RawRes(R.raw.wave_teal))
    val progress by animateLottieCompositionAsState(
        composition = composition,
        iterations = LottieConstants.IterateForever
    )
    Box(Modifier.padding(bottom = 72.dp)) {
        LottieAnimation(
            composition = composition,
            progress = progress,
            modifier = Modifier.fillMaxSize()
        )
    }
}

@Composable
fun ActionIcons(
    imageVector: ImageVector,
    isPrimary: Boolean,
    navigateTo: String,
    mainViewModel: MainViewModel,
    historyViewModel: HistoryViewModel
) {
    val infiniteTransition = rememberInfiniteTransition()
    val scale by infiniteTransition.animateFloat(
        initialValue = 0.95f,
        targetValue = 1.1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        )
    )

    val buttonBackground by infiniteTransition.animateColor(
        initialValue = accentLow2,
        targetValue = accentHigh1,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        )
    )

    val primaryIconTint by infiniteTransition.animateColor(
        initialValue = Color.White,
        targetValue = accentLow1,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        )
    )

    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        CoachMarkOverChatIcon(isVisible = (navigateTo == Constants.VIEWS.CHAT_VIEW.str && !mainViewModel.hasUserEverClickedOnChat()))

        Box(
            modifier = Modifier
                .graphicsLayer {
                    if (isPrimary) {
                        scaleX = scale
                        scaleY = scale
                    }
                }
                .height(if (isPrimary) 64.dp else 52.dp)
                .width(if (isPrimary) 64.dp else 52.dp)
                .clip(CircleShape)
                .background(if (isPrimary) buttonBackground else accentLow2)
                .clickable {
                    if (navigateTo == Constants.VIEWS.CHAT_VIEW.str) mainViewModel.registerUserTapToChat()
                    if (navigateTo == Constants.VIEWS.HISTORY_VIEW.str) historyViewModel.updateChatHistory()

                    GlobalState.navController!!.navigate(navigateTo)
                },
            contentAlignment = Alignment.Center
        ) {
            Icon(
                imageVector = imageVector,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = if (isPrimary) primaryIconTint else Color.White
            )
        }
    }
}

@Composable
fun CoachMarkOverChatIcon(isVisible: Boolean) {
    val infiniteTransition = rememberInfiniteTransition()
    val yFloat by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = -12f,
        animationSpec = infiniteRepeatable(
            tween(1000, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        )
    )

    Box(
        modifier = Modifier
            .offset(y = yFloat.dp)
    ) {
        Box(
            Modifier.height(24.dp)
        ) {
            if (isVisible) {
                Text(
                    "Tap to Chat",
                    style = MaterialTheme.typography.bodySmall.copy(color = Color.Gray),
                    modifier = Modifier.padding(bottom = 8.dp)
                )
            }
        }
    }
}
