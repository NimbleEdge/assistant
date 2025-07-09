/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

package dev.deliteai.assistant.domain.models

import java.util.Date

data class HistoryItem(
    val parentChatId: String,
    val title: String,
    val dateTime: Date
)
