/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.accent
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.backgroundSecondary
import ai.nimbleedge.nimbleedge_chatbot.presentation.ui.theme.textPrimary
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.expandVertically
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.shrinkVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

@Composable
fun ScrollableTextSuggestions(
    isVisible: Boolean,
    onClick: (String) -> Unit
) {
    val allSuggestions = remember {
        listOf(
            "Design workout routine",
            "Recommend wine pairings",
            "Write a short poem",
            "Draft party menu",
            "Create smoothie blends",
            "Generate gift ideas",
            "Craft cocktail ideas",
            "Mix mocktail recipes",
            "Suggest hiking essentials",
            "Plan a game night",
            "Prep for camping",
            "Plan a movie marathon",
            "Invent signature cocktail",
            "Craft lunchbox ideas",
            "Who are you?",
            "Plan a solo trip",
            "Curate weekend playlist",
            "Plan a beach day"
        )
    }

    var picks by remember { mutableStateOf<List<String>>(emptyList()) }

    LaunchedEffect(isVisible) {
        if (isVisible) {
            val newPicks = withContext(Dispatchers.Default) {
                allSuggestions.shuffled().take(4)
            }
            picks = newPicks
        } else {
            picks = emptyList()
        }
    }

    AnimatedVisibility(
        visible = isVisible && picks.isNotEmpty(),
        enter = fadeIn(tween(300)) + expandVertically(tween(300)),
        exit = fadeOut(tween(200)) + shrinkVertically(tween(200))
    ) {
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(picks) { suggestion ->
                Text(
                    suggestion,
                    modifier = Modifier
                        .background(backgroundSecondary, shape = RoundedCornerShape(16.dp))
                        .clickable { onClick(suggestion) }
                        .border(width = 1.dp, color = accent, shape = RoundedCornerShape(16.dp))
                        .padding(horizontal = 12.dp, vertical = 8.dp),
                    style = MaterialTheme.typography.bodyMedium.copy(fontSize = 12.sp),
                    color = textPrimary
                )
            }
        }
    }
}
