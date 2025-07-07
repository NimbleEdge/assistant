/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.presentation.viewmodels

import ai.nimbleedge.nimbleedge_chatbot.domain.models.ChatMessage
import ai.nimbleedge.nimbleedge_chatbot.domain.models.HistoryItem
import ai.nimbleedge.nimbleedge_chatbot.domain.repositories.CacheRepository
import android.app.Application
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.AndroidViewModel

class HistoryViewModel(private val application: Application) : AndroidViewModel(application) {
    private val cacheRepository = CacheRepository(application)
    var chatHistory = mutableStateOf<List<HistoryItem>?>(
        null
    )

    fun updateChatHistory(){
        chatHistory.value = retrieveChatHistory()
    }

    fun searchInChatHistory(chatId: String, searchQuery: String): Boolean {
        val chat = cacheRepository.retrieveChat(chatId)
        var searchCandidate = ""

        chat.messages.forEach {
            searchCandidate += it.message ?: ""
        }

        return searchCandidate.contains(searchQuery, ignoreCase = true)
    }

    fun deleteChat(id: String) {
        val currentHistory = chatHistory.value ?: return

        chatHistory.value = currentHistory.toMutableList().filterNot {
            it.parentChatId == id
        }

        cacheRepository.deleteChat(id)
    }

   private fun retrieveChatHistory(): List<HistoryItem> {
        val historyCards = mutableListOf<HistoryItem>()
        val chatIds = cacheRepository.getChatIds()

        chatIds.forEach {
            val chat = cacheRepository.retrieveChat(it)

            if(chat.messages.isEmpty()) return@forEach

            var firstNonEmptyChat: ChatMessage = chat.messages[0]

            for (message in chat.messages) {
                if (message.message != "") {
                    firstNonEmptyChat = message
                    break
                }
            }

            historyCards.add(
                HistoryItem(
                    chat.id,
                    firstNonEmptyChat.message ?: "Empty Conversation",
                    firstNonEmptyChat.timestamp
                )
            )
        }

        return historyCards.reversed()
    }
}