/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.presentation.components

import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.accent
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.backgroundSecondary
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalFocusManager
import androidx.compose.ui.unit.dp

@Composable
fun StyledTextField(
    isLoading: Boolean,
    icon: ImageVector,
    onButtonClick: (String) -> Unit
) {
    val inputValue = remember { mutableStateOf("") }
    val focusManager = LocalFocusManager.current

    Box(
        modifier = Modifier
            .clip(RoundedCornerShape(8.dp))
            .background(backgroundSecondary)
            .height(52.dp)
            .fillMaxWidth()
    ) {
        TextField(
            value = inputValue.value,
            onValueChange = { inputValue.value = it },
            modifier = Modifier.fillMaxSize(),
            placeholder = {
                Text("Ask me anything", style = MaterialTheme.typography.bodyMedium)
            },
            textStyle = MaterialTheme.typography.bodyMedium,
            trailingIcon = {
                if (isLoading) {
                    CircularProgressIndicator(
                        Modifier
                            .align(Alignment.Center)
                            .size(20.dp), color = accent
                    )
                } else {
                    IconButton(
                        onClick = {
                            onButtonClick(inputValue.value)
                            inputValue.value = ""
                            focusManager.clearFocus()
                        }
                    ) {
                        Icon(
                            icon,
                            contentDescription = null,
                            tint = accent
                        )
                    }
                }
            },
            colors = TextFieldDefaults.colors(
                focusedContainerColor = backgroundSecondary,
                unfocusedContainerColor = backgroundSecondary,
                disabledContainerColor = backgroundSecondary,
                cursorColor = MaterialTheme.colorScheme.primary,
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
            ),
            singleLine = true
        )
    }
}