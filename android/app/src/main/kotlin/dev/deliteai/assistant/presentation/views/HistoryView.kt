/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.presentation.views

import dev.deliteai.assistant.domain.models.HistoryItem
import dev.deliteai.assistant.presentation.components.HamburgerMenu
import dev.deliteai.assistant.presentation.components.TopBar
import dev.deliteai.assistant.presentation.ui.theme.accent
import dev.deliteai.assistant.presentation.ui.theme.accentHigh1
import dev.deliteai.assistant.presentation.ui.theme.accentLow2
import dev.deliteai.assistant.presentation.ui.theme.backgroundSecondary
import dev.deliteai.assistant.presentation.ui.theme.textPrimary
import dev.deliteai.assistant.presentation.ui.theme.textSecondary
import dev.deliteai.assistant.presentation.viewmodels.ChatViewModel
import dev.deliteai.assistant.presentation.viewmodels.HistoryViewModel
import dev.deliteai.assistant.utils.Constants
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.WindowInsetsSides
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.only
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CenterAlignedTopAppBar
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.TimeUnit

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryView(
    historyViewModel: HistoryViewModel,
    chatViewModel: ChatViewModel,
    navController: NavController
) {
    val searchQuery = remember { mutableStateOf("") }
    var drawerOpen by remember { mutableStateOf(false) }
    var showConfirmDialog by remember { mutableStateOf(false) }
    val selectedItems = remember { mutableStateListOf<String>() }
    val isSelectionMode = selectedItems.isNotEmpty()

    LaunchedEffect(Unit) {
        historyViewModel.updateChatHistory()
    }


    val clearSelectionModifier = if (isSelectionMode) {
        Modifier.pointerInput(Unit) {
            detectTapGestures { selectedItems.clear() }
        }
    } else {
        Modifier
    }

    Column(
        Modifier
            .fillMaxSize()
            .then(clearSelectionModifier)
    ) {

        if (isSelectionMode) {
            CenterAlignedTopAppBar(
                windowInsets = WindowInsets.statusBars.only(WindowInsetsSides.Horizontal),
                modifier = Modifier
                    .fillMaxWidth()
                    .height(65.dp),
                title = {
                    Text(
                        "${selectedItems.size} selected",
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier
                            .fillMaxHeight()
                            .wrapContentHeight(Alignment.CenterVertically)
                    )
                },
                navigationIcon = {
                    IconButton(
                        onClick = { selectedItems.clear() },
                        modifier = Modifier
                            .fillMaxHeight()
                            .wrapContentHeight(Alignment.CenterVertically)
                    ) {
                        Icon(Icons.Default.Close, contentDescription = "Cancel selection")
                    }
                },
                actions = {
                    IconButton(
                        onClick = { showConfirmDialog = true },
                        modifier = Modifier
                            .fillMaxHeight()
                            .wrapContentHeight(Alignment.CenterVertically)
                    ) {
                        Icon(
                            Icons.Default.Delete,
                            contentDescription = "Delete",
                            tint = Color.White
                        )
                    }
                }
            )
        } else {
            TopBar(
                chatViewModel = chatViewModel,
                isHistoryView = true,
                navController = navController,
                title = "Your Conversations"
            )
        }

        Spacer(Modifier.height(20.dp))

        Column(Modifier.padding(horizontal = 24.dp)) {

            if (historyViewModel.chatHistory.value?.isNotEmpty() == true) {
                BasicTextField(
                    value = searchQuery.value,
                    onValueChange = { searchQuery.value = it },
                    singleLine = true,
                    textStyle = MaterialTheme.typography.bodyMedium.copy(color = textPrimary),
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(48.dp)
                        .background(backgroundSecondary, shape = RoundedCornerShape(8.dp)),
                    decorationBox = { inner ->
                        Box(
                            Modifier
                                .fillMaxSize()
                                .padding(horizontal = 12.dp),
                            Alignment.CenterStart
                        ) {
                            if (searchQuery.value.isEmpty()) {
                                Text(
                                    "Search...",
                                    style = MaterialTheme.typography.bodyMedium.copy(color = textSecondary)
                                )
                            }
                            inner()
                        }
                    }
                )
                Spacer(Modifier.height(16.dp))
            }
            when {
                historyViewModel.chatHistory.value == null -> {
                    Box(Modifier.fillMaxSize(), Alignment.Center) {
                        CircularProgressIndicator(color = accentHigh1)
                    }
                }

                historyViewModel.chatHistory.value!!.isEmpty() -> {
                    Column(Modifier.fillMaxSize(), verticalArrangement = Arrangement.Center) {
                        Text(
                            "No History",
                            style = MaterialTheme.typography.titleLarge.copy(fontSize = 20.sp),
                            modifier = Modifier.fillMaxWidth(),
                            textAlign = TextAlign.Center
                        )
                        Spacer(Modifier.height(8.dp))
                        Text(
                            "Start a new conversation to see it here",
                            style = MaterialTheme.typography.bodyMedium.copy(color = textSecondary),
                            modifier = Modifier.fillMaxWidth(),
                            textAlign = TextAlign.Center
                        )
                    }
                }

                else -> {
                    val filtered = historyViewModel.chatHistory.value!!
                        .filter {
                            historyViewModel.searchInChatHistory(
                                it.parentChatId,
                                searchQuery.value
                            )
                        }


                    val groupedHistory: Map<String, List<HistoryItem>> = filtered.groupBy { item ->
                        val diffDays = TimeUnit.MILLISECONDS.toDays(
                            Calendar.getInstance().timeInMillis - item.dateTime.time
                        )
                        when {
                            diffDays == 0L -> "Today"
                            diffDays in 1..3 -> "Previous 3 Days"
                            diffDays in 4..7 -> "Previous 7 Days"
                            diffDays in 8..30 -> "Previous 30 Days"
                            else -> "Older"
                        }
                    }

                    val categoryOrder = listOf(
                        "Today", "Previous 3 Days", "Previous 7 Days", "Previous 30 Days", "Older"
                    )

                    Column(
                        Modifier
                            .fillMaxWidth()
                            .verticalScroll(rememberScrollState())
                    ) {
                        categoryOrder.forEach { category ->
                            groupedHistory[category]?.let { items ->

                                Row(
                                    verticalAlignment = Alignment.CenterVertically,
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Box(
                                        Modifier
                                            .weight(1f)
                                            .height(1.dp)
                                            .background(accentLow2)
                                    )
                                    Text(
                                        category,
                                        Modifier.padding(horizontal = 8.dp),
                                        style = MaterialTheme.typography.bodySmall.copy(
                                            color = accent,
                                            fontWeight = androidx.compose.ui.text.font.FontWeight.SemiBold
                                        )
                                    )
                                    Box(
                                        Modifier
                                            .weight(1f)
                                            .height(1.dp)
                                            .background(accentLow2)
                                    )
                                }

                                Spacer(Modifier.height(12.dp))


                                items.forEach { historyItem ->
                                    HistoryCardItem(
                                        history = historyItem,
                                        isSelected = selectedItems.contains(historyItem.parentChatId),
                                        onClick = {
                                            if (isSelectionMode) {
                                                if (!selectedItems.remove(historyItem.parentChatId)) {
                                                    selectedItems.add(historyItem.parentChatId)
                                                }
                                            } else {
                                                navController.navigate("chatView/${historyItem.parentChatId}")
                                            }
                                        },
                                        onLongClick = {
                                            if (!selectedItems.remove(historyItem.parentChatId)) {
                                                selectedItems.add(historyItem.parentChatId)
                                            }
                                        }
                                    )

                                    Spacer(Modifier.height(8.dp))
                                }

                                Spacer(Modifier.height(24.dp))
                            }
                        }
                    }
                }
            }
        }
    }


    if (showConfirmDialog) {
        AlertDialog(
            onDismissRequest = { showConfirmDialog = false },
            title = { Text("Delete ${selectedItems.size} conversation(s)?") },
            text = { Text("Warning: This will permanently delete your conversation(s).") },
            containerColor = backgroundSecondary,
            confirmButton = {
                TextButton(onClick = {
                    selectedItems.forEach { historyViewModel.deleteChat(it) }
                    selectedItems.clear()
                    showConfirmDialog = false
                }) {
                    Text("Delete", color = accentHigh1)
                }
            },
            dismissButton = {
                TextButton(onClick = { showConfirmDialog = false }) {
                    Text("Cancel", color = Color.White.copy(alpha = 0.8f))
                }
            }
        )
    }

    HamburgerMenu(
        isOpen = drawerOpen,
        currentView = Constants.VIEWS.HISTORY_VIEW,
        historyViewModel = historyViewModel,
        chatViewModel = chatViewModel,
        onDismiss = { drawerOpen = false }
    )
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun HistoryCardItem(
    history: HistoryItem,
    isSelected: Boolean,
    onClick: () -> Unit,
    onLongClick: () -> Unit
) {
    val date = SimpleDateFormat("d MMMM, yyyy", Locale.getDefault()).format(history.dateTime)
    val time = SimpleDateFormat("HH:mm", Locale.getDefault()).format(history.dateTime)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .combinedClickable(onClick = onClick, onLongClick = onLongClick)
            .background(
                color = if (isSelected)
                    accent.copy(alpha = 0.2f)
                else
                    Color.Transparent,
                shape = RoundedCornerShape(8.dp)
            )
            .padding(vertical = 8.dp, horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                history.title,
                style = MaterialTheme.typography.titleSmall,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Spacer(Modifier.height(4.dp))
            Text(
                "$date • $time",
                style = MaterialTheme.typography.bodySmall.copy(color = textSecondary)
            )
        }
    }
}
