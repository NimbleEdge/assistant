/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
struct HistoryItem {
    let parentChatId: String
    let title: String
    let dateTime: Date
    let chats: [ChatMessage]
}
