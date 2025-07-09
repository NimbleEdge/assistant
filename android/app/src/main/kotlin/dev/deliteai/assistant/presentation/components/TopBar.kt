/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.presentation.components

import dev.deliteai.assistant.presentation.ui.theme.accent
import dev.deliteai.assistant.presentation.ui.theme.backgroundSecondary
import dev.deliteai.assistant.presentation.viewmodels.ChatViewModel
import dev.deliteai.assistant.utils.Constants
import android.app.Application
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBackIos
import androidx.compose.material.icons.rounded.Create
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController

@Composable
fun TopBar(
    chatViewModel: ChatViewModel,
    isHistoryView: Boolean = false,
    navController: NavController,
    isLoading: Boolean = false,
    title: String?
) {
    val application = LocalContext.current.applicationContext as Application
    val iconTint = if (isLoading) Color.Gray else Color.White

    Column {
        Row(
            Modifier
                .fillMaxWidth()
                .padding(vertical = 8.dp, horizontal = 24.dp)
                .height(56.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.AutoMirrored.Filled.ArrowBackIos,
                contentDescription = "back",
                tint = accent,
                modifier = Modifier
                    .size(20.dp)
                    .clickable {
                        navController.popBackStack()
                    }
            )

            Spacer(Modifier.width(12.dp))

            Text(
                title ?: "",
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Medium
                )
            )

            Spacer(Modifier.weight(1f))

            IconButton(onClick = {
                if (isLoading) {
                    Toast.makeText(
                        application,
                        "Loading your conversation… please wait",
                        Toast.LENGTH_SHORT
                    )
                        .show()
                } else if (isHistoryView) {
                    navController.navigate(Constants.VIEWS.VOICE_VIEW.str)
                } else {
                    chatViewModel.isOverlayVisible.value = true
                }

            }) {
                Icon(
                    Icons.Rounded.GraphicEq,
                    contentDescription = "New voice chat",
                    tint = iconTint
                )
            }

            Spacer(Modifier.width(4.dp))

            IconButton(onClick = {
                if (isLoading) {
                    Toast.makeText(
                        application,
                        "Loading your conversation… please wait",
                        Toast.LENGTH_SHORT
                    )
                        .show()
                } else if (isHistoryView) {
                    navController.navigate(Constants.VIEWS.CHAT_VIEW.str)
                }

                chatViewModel.clearContextAndStartNewChat()

            }) {
                Icon(
                    Icons.Rounded.Create,
                    contentDescription = "New chat",
                    tint = iconTint
                )
            }

        }
        HorizontalDivider(
            Modifier
                .height(1.dp)
                .background(backgroundSecondary.copy(alpha = 0.5f))
        )
    }
}
