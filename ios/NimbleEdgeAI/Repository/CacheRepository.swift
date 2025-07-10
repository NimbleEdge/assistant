/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class CacheRepository {
    private let maxHistorySize = 25
    private let prefs = UserDefaults.standard
    private let chatIdsKey = "chat_ids"
    private let firstBootKey = "first_boot"
    private let firstChatKey = "first_chat"

    func cacheChat(_ chat: Chat) {
        var chatIds = getChatIds()
        if !chatIds.contains(chat.id) && !chat.messages.isEmpty {
            if chatIds.count == maxHistorySize {
                chatIds.removeFirst()
            }
            chatIds.append(chat.id)
            saveChatIds(chatIds)
        }

        prefs.set(chat.toString(), forKey: chat.id)
    }

    func retrieveChat(id: String) -> Chat? {
        let chatString = prefs.string(forKey: id) ?? ""
        return Chat.fromString(chatString)
    }

    func getChatIds() -> [String] {
        let chatIdsString = prefs.string(forKey: chatIdsKey) ?? ""
        return chatIdsString.isEmpty ? [] : chatIdsString.components(separatedBy: ",")
    }

    func registerUserFirstBoot() {
        prefs.set(false, forKey: firstBootKey)
    }

    func isFirstBoot() -> Bool {
        return prefs.bool(forKey: firstBootKey) == false ? true : false
    }

    func hasUserEverClickedOnChat() -> Bool {
        return prefs.bool(forKey: firstChatKey)
    }

    func registerUserTapToChat() {
        prefs.set(true, forKey: firstChatKey)
    }

    func deleteChat(id: String) {
        deleteChatId(id)
        deleteChatHistory(id)
    }

    private func deleteChatId(_ id: String) {
        var chatIds = getChatIds()
        if let index = chatIds.firstIndex(of: id) {
            chatIds.remove(at: index)
            saveChatIds(chatIds)
        }
    }

    private func deleteChatHistory(_ id: String) {
        prefs.removeObject(forKey: id)
    }

    private func saveChatIds(_ chatIds: [String]) {
        prefs.set(chatIds.joined(separator: ","), forKey: chatIdsKey)
    }
}
