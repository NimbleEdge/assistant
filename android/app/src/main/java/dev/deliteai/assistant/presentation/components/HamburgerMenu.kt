/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.presentation.components

import ai.nimbleedge.nimbleedge_chatbot.R
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.accent
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.accentLow1
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.backgroundSecondary
import ai.nimbleedge.nimbleedge_chatbot.presentation.viewmodels.ChatViewModel
import ai.nimbleedge.nimbleedge_chatbot.presentation.viewmodels.HistoryViewModel
import ai.nimbleedge.nimbleedge_chatbot.utils.Constants
import ai.nimbleedge.nimbleedge_chatbot.utils.GlobalState
import ai.nimbleedge.nimbleedge_chatbot.utils.openUrlInBrowser
import android.app.Application
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Policy
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.ColorFilter
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun HamburgerMenu(
    isOpen: Boolean,
    currentView: Constants.VIEWS,
    onDismiss: () -> Unit,
    width: Dp = 280.dp,
    historyViewModel: HistoryViewModel,
    chatViewModel: ChatViewModel
) {
    val offsetX by animateDpAsState(targetValue = if (isOpen) 0.dp else -width)
    val application = LocalContext.current.applicationContext as Application

    Box(Modifier.fillMaxWidth()) {
        if (isOpen) {
            Box(
                Modifier
                    .fillMaxSize()
                    .clickable { onDismiss() }
            )
        }

        Box(
            Modifier
                .offset(x = offsetX)
                .width(width)
                .fillMaxHeight()
                .clip(RoundedCornerShape(topEnd = 16.dp, bottomEnd = 16.dp))
                .background(backgroundSecondary)
                .padding(vertical = 24.dp)
        ) {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Spacer(Modifier.width(16.dp))
                    Image(
                        painter = painterResource(R.drawable.ic_ne_new),
                        contentDescription = null,
                        colorFilter = ColorFilter.tint(Color.White),
                        modifier = Modifier.size(16.dp)
                    )
                    Spacer(Modifier.width(8.dp))
                    Text(
                        text = buildAnnotatedString {
                            append("NimbleEdge ")
                            withStyle(style = SpanStyle(color = accent)) { append("AI") }
                        },
                        style = MaterialTheme.typography.bodyLarge.copy(
                            fontSize = 16.sp,
                            fontWeight = FontWeight.SemiBold
                        ),
                        textAlign = TextAlign.Center
                    )
                }

                HorizontalDivider(Modifier.padding(vertical = 20.dp))

                DrawerMenuItem(icon = Icons.Default.Edit, label = "New Chat") {
                    chatViewModel.clearContextAndStartNewChat()
                    GlobalState.navController!!.navigate(Constants.VIEWS.CHAT_VIEW.str)
                }

                Spacer(Modifier.height(8.dp))

                DrawerMenuItem(
                    icon = Icons.Default.History,
                    label = "Chat History",
                    isSelected = currentView == Constants.VIEWS.HISTORY_VIEW
                ) {
                    if (currentView != Constants.VIEWS.HISTORY_VIEW) {
                        historyViewModel.updateChatHistory()
                        GlobalState.navController!!.navigate(Constants.VIEWS.HISTORY_VIEW.str)
                    }
                }

                Spacer(Modifier.height(8.dp))

                DrawerMenuItem(icon = Icons.Default.Email, label = "Contact & Feedback") {
                    openUrlInBrowser(application, "https://nimbleedge.com/contact")
                }

                Spacer(Modifier.weight(1f))
                HorizontalDivider(Modifier.padding(vertical = 20.dp))

                DrawerMenuItem(icon = Icons.Default.Policy, label = "Privacy Policy") {
                    openUrlInBrowser(application, "https://www.nimbleedge.com/nimbleedge-ai-privacy-policy")
                }
            }
        }
    }
}

@Composable
private fun DrawerMenuItem(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    isSelected: Boolean = false,
    onClick: () -> Unit
) {
    val backgroundColor = if (isSelected) accentLow1 else Color.Transparent

    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(backgroundColor)
            .clickable(onClick = onClick)
            .padding(16.dp)
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Icon(
                imageVector = icon,
                contentDescription = label,
                tint = Color.White
            )
            Spacer(Modifier.width(16.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.bodyMedium.copy(
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White
                )
            )
        }
    }
}

