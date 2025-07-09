/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.domain.models

import org.json.JSONObject
import java.util.Date
import java.util.UUID

data class ChatMessage(
    val message: String?,
    val isUserMessage: Boolean,
    val timestamp: Date,
    val tps: Float? = null
) {
    override fun toString(): String {
        val json = JSONObject()
        json.put("message", message)
        json.put("isUserMessage", isUserMessage)
        json.put("timestamp", timestamp.time)
        json.put("tps", tps ?: JSONObject.NULL)
        return json.toString()
    }

    companion object {
        fun fromString(str: String): ChatMessage {
            val json = JSONObject(str)
            val message = if (json.isNull("message")) null else json.getString("message")
            val isUserMessage = json.getBoolean("isUserMessage")
            val timestamp = Date(json.getLong("timestamp"))
            val tps = if (json.isNull("tps")) null else json.getDouble("tps").toFloat()
            return ChatMessage(message, isUserMessage, timestamp, tps)
        }
    }
}
