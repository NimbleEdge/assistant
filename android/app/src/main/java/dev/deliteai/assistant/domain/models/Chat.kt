/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package ai.nimbleedge.nimbleedge_chatbot.domain.models

import org.json.JSONArray
import org.json.JSONObject
import java.util.Date
import java.util.UUID

data class Chat(
    val messages: List<ChatMessage>,
    val id: String,
) {
    override fun toString(): String {
        val json = JSONObject()
        json.put("id", id)
        val messagesArray = JSONArray()
        messages.forEach { message ->
            messagesArray.put(JSONObject(message.toString()))
        }
        json.put("messages", messagesArray)
        return json.toString()
    }

    companion object {
        fun fromString(str: String): Chat {
            val json = JSONObject(str)
            val id = json.getString("id")
            val messagesArray = json.getJSONArray("messages")
            val messagesList = mutableListOf<ChatMessage>()
            for (i in 0 until messagesArray.length()) {
                val messageJson = messagesArray.getJSONObject(i)
                val message = ChatMessage.fromString(messageJson.toString())
                messagesList.add(message)
            }
            return Chat(messages = messagesList, id = id)
        }
    }
}
