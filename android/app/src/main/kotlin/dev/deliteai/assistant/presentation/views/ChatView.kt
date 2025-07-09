/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.presentation.views

import ScrollableTextSuggestions
import dev.deliteai.assistant.domain.models.ChatMessage
import dev.deliteai.assistant.presentation.components.MessageBox
import dev.deliteai.assistant.presentation.components.StyledTextField
import dev.deliteai.assistant.presentation.components.TopBar
import dev.deliteai.assistant.presentation.components.VoiceOverlay
import dev.deliteai.assistant.presentation.ui.theme.accent
import dev.deliteai.assistant.presentation.ui.theme.backgroundPrimary
import dev.deliteai.assistant.presentation.ui.theme.backgroundSecondary
import dev.deliteai.assistant.presentation.ui.theme.textSecondary
import dev.deliteai.assistant.presentation.viewmodels.ChatViewModel
import dev.deliteai.assistant.utils.Constants
import android.app.Application
import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.LinearOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.gestures.animateScrollBy
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyListState
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.StopCircle
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.derivedStateOf
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.runtime.withFrameNanos
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.positionInRoot
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.platform.LocalSoftwareKeyboardController
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.DpOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.navigation.NavController
import kotlinx.coroutines.launch
import java.util.Date

@Composable
fun ChatView(
    chatViewModel: ChatViewModel,
    navController: NavController,
    isVoiceOverlayRequested: Boolean,
    chatId: String? = null
) {
    val pendingOutput by chatViewModel.outputStream
    val chats by chatViewModel.chatHistory
    val application = LocalContext.current.applicationContext as Application
    val isOverlayActive by chatViewModel.isOverlayVisible
    val isHistoryLoadInProgress by chatViewModel.isHistoryLoadInProgress
    val listState = rememberLazyListState()
    val coroutineScope = rememberCoroutineScope()
    val keyboardController = LocalSoftwareKeyboardController.current
    var hasScrolledOnce by remember { mutableStateOf(false) }
    val showScrollButton by remember {
        derivedStateOf {
            hasScrolledOnce && !(chats.isEmpty() && chatViewModel.outputStream.value == null) && listState.canScrollForward
        }
    }

    var longPressOffset by remember { mutableStateOf(Offset.Zero) }

    val infiniteTransition = rememberInfiniteTransition(label = "")
    val offsetY by infiniteTransition.animateFloat(
        initialValue = 0f,
        targetValue = -8f,
        animationSpec = infiniteRepeatable(
            animation = tween(600, easing = LinearOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ), label = ""
    )

    suspend fun LazyListState.scrollToBottom() {
        val animationDuration = if (chats.size > 10) 20 else 100

        withFrameNanos { }
        val pageSize = layoutInfo.viewportEndOffset.toFloat()
        while (canScrollForward) {
            animateScrollBy(
                pageSize,
                animationSpec = tween(durationMillis = animationDuration, easing = LinearEasing)
            )
            withFrameNanos { }
        }
    }


    LaunchedEffect(isVoiceOverlayRequested) {
        chatViewModel.isOverlayVisible.value = isVoiceOverlayRequested
    }

    LaunchedEffect(Unit) {
        if (chatId != null) {
            chatViewModel.loadChatFromId(chatId)
            Toast.makeText(
                application,
                "Loading your conversation… please wait",
                Toast.LENGTH_SHORT
            ).show()
        } else chatViewModel.clearContextAndStartNewChat()

        chatViewModel.fetchModelName()
    }

    //opening chat via history, must scroll to the very bototm
    LaunchedEffect(chats.size) {
        if (!hasScrolledOnce and chats.isNotEmpty()) {
            listState.scrollToBottom()
            hasScrolledOnce = true
        }
    }

    BackHandler(enabled = chatViewModel.isOverlayVisible.value) {
        hasScrolledOnce = false
        chatViewModel.handleBack()
    }

    if (chatViewModel.isChatScreenLoading.value) {
        Box(Modifier.fillMaxSize()) {
            CircularProgressIndicator(modifier = Modifier.align(Alignment.Center))
        }
    } else {
        Box(
            Modifier
                .fillMaxSize()
                .background(backgroundPrimary)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxSize()
            ) {
                TopBar(
                    chatViewModel,
                    navController = navController,
                    isLoading = isHistoryLoadInProgress,
                    title = chatViewModel.topBarTitle.value
                )

                Column(Modifier.padding(24.dp)) {
                    if (chats.isEmpty()) {
                        Box(
                            Modifier
                                .fillMaxSize()
                                .weight(1f),
                            contentAlignment = Alignment.Center
                        ) {
                            Column(Modifier.padding(bottom = 100.dp)) {
                                Text(
                                    "How can I help you today?",
                                    style = MaterialTheme.typography.titleLarge.copy(fontSize = 20.sp),
                                    modifier = Modifier.fillMaxWidth(),
                                    textAlign = TextAlign.Center
                                )
                                Spacer(Modifier.height(8.dp))
                                Text(
                                    "You can use NimbleEdge AI while being completely offline. Give it a try!",
                                    style = MaterialTheme.typography.bodyMedium.copy(color = textSecondary),
                                    modifier = Modifier.fillMaxWidth(),
                                    textAlign = TextAlign.Center
                                )
                            }
                        }
                    } else {
                        val currentChats = chats + getStreamingChatMessage(
                            pendingOutput,
                            chatViewModel.currentTPS.value
                        )

                        LazyColumn(
                            state = listState,
                            modifier = Modifier
                                .fillMaxWidth()
                                .weight(1f)
                        ) {
                            itemsIndexed(
                                items = currentChats,
                                key = { index, _ -> index }
                            ) { idx, msg ->
                                MessageBox(
                                    msg,
                                    chatViewModel,
                                    isInProgress = idx == currentChats.lastIndex && chatViewModel.isChattingJobActive(),
                                    onLongTap = { localOffset, layoutCoordinates ->

                                        // Convert local offset to root coordinates
                                        val rootPosition = layoutCoordinates.positionInRoot()
                                        longPressOffset = Offset(
                                            rootPosition.x + localOffset.x,
                                            rootPosition.y + localOffset.y
                                        )

                                        chatViewModel.longTapMenuMessage.value = msg
                                    }
                                )
                                Spacer(Modifier.height(8.dp))
                            }
                            item { Spacer(Modifier.height(12.dp)) }
                        }
                    }
                    Box(Modifier.padding(top = 8.dp)) {
                        Column {
                            ScrollableTextSuggestions(!chatViewModel.isFirstMessageSent.value && !isHistoryLoadInProgress) {
                                keyboardController?.hide()

                                chatViewModel.addNewMessageToChatHistory(it, true)
                                chatViewModel.getLLMTextFromTextInput(it)
                            }
                            Spacer(Modifier.height(8.dp))

                            StyledTextField(
                                isHistoryLoadInProgress,
                                icon = if (chatViewModel.isChattingJobActive()) Icons.Filled.StopCircle else Icons.AutoMirrored.Filled.Send,
                                onButtonClick = { userInput ->
                                    chatViewModel.handleTextViewButtonClick(userInput)
                                    coroutineScope.launch {
                                        listState.scrollToBottom()
                                    }
                                })
                        }
                    }
                }
            }

            LongTapMenu(chatViewModel, longPressOffset)

            if (showScrollButton) {
                IconButton(
                    onClick = {
                        coroutineScope.launch {
                            listState.scrollToBottom()
                        }
                    },
                    modifier = Modifier
                        .align(Alignment.BottomCenter)
                        .padding(bottom = 80.dp)
                        .offset(y = offsetY.dp)
                        .background(accent, RoundedCornerShape(50))
                ) {
                    Icon(
                        imageVector = Icons.Default.ArrowDownward,
                        contentDescription = "Scroll to bottom",
                        tint = Color.White
                    )
                }
            }

            if (isOverlayActive) VoiceOverlay(chatViewModel)
        }
    }
}

fun getStreamingChatMessage(pendingOutput: String?, tps: Float?): ChatMessage {
    return ChatMessage(
        message = pendingOutput,
        isUserMessage = false,
        timestamp = Date(),
        tps = tps
    )
}

@Composable
fun BoxScope.LongTapMenu(
    chatViewModel: ChatViewModel,
    pressOffset: Offset
) {
    val density = LocalDensity.current

    DropdownMenu(
        containerColor = backgroundSecondary,
        expanded = chatViewModel.longTapMenuMessage.value != null,
        onDismissRequest = { chatViewModel.longTapMenuMessage.value = null },
        offset = with(density) {
            DpOffset(pressOffset.x.toDp(), pressOffset.y.toDp())
        },
        modifier = Modifier
            .clip(RoundedCornerShape(12.dp))
    ) {
        DropdownMenuItem(
            text = { Text("Copy To Clipboard") },
            leadingIcon = { Icon(Icons.Filled.ContentCopy, contentDescription = "Copy") },
            onClick = {
                chatViewModel.handleMessageLongTapAction(Constants.MESSAGE_LONG_TAP_ACTIONS.COPY)
            }
        )

        if (chatViewModel.longTapMenuMessage.value?.isUserMessage == false) {
            DropdownMenuItem(
                text = { Text("Flag For Review") },
                leadingIcon = { Icon(Icons.Filled.Flag, contentDescription = "Flag") },
                onClick = {
                    chatViewModel.handleMessageLongTapAction(Constants.MESSAGE_LONG_TAP_ACTIONS.FLAG)
                }
            )
        }
    }
}
