/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class HistoryViewModel: ObservableObject {
    private let cacheRepository: CacheRepository
    
    @Published var chatHistory: [HistoryItem]? = nil
    @Published var chatHistoryFiltered: [ArrangedHistoryItem] = [ArrangedHistoryItem]()
    @Published var searchedChatHistory: [HistoryItem]? = nil
    
    init() {
        self.cacheRepository = CacheRepository()
    }
    
    func updateChatHistory() {
        chatHistory = retrieveChatHistory()
        chatHistoryFiltered = filterAndGroupHistory(chatHistory: chatHistory ?? [])
    }
    
    func searchInChatHistory(chatId: String, searchQuery: String) -> Bool {
        guard let chat = cacheRepository.retrieveChat(id: chatId) else{ return false}
        
        let searchCandidate = chat.messages.compactMap { $0.message }.joined()
        
        return searchCandidate.range(of: searchQuery, options: .caseInsensitive) != nil
    }
    
    private func retrieveChatHistory() -> [HistoryItem] {
        var historyCards: [HistoryItem] = []
        
        let chatIds = cacheRepository.getChatIds()
        
        for id in chatIds {
            
            guard let chat = cacheRepository.retrieveChat(id: id) else { continue }
            
            if !chat.messages.isEmpty {
                var firstNonEmptyChat = chat.messages[0]
                for message in chat.messages {
                    if let text = message.message, !text.isEmpty {
                        firstNonEmptyChat = message
                        break
                    }
                }
                
                let historyItem = HistoryItem(
                    parentChatId: chat.id,
                    title: firstNonEmptyChat.message ?? "Empty Conversation",
                    dateTime: firstNonEmptyChat.timestamp,
                    chats: chat.messages
                )
                
                historyCards.append(historyItem)
            }
            
        }
        
        return historyCards.reversed()
    }
    
    func filterAndGroupHistory(chatHistory: [HistoryItem]) -> [ArrangedHistoryItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var todayItems: [HistoryItem] = []
        var previous3DaysItems: [HistoryItem] = []
        var previous7DaysItems: [HistoryItem] = []
        var previous30DaysItems: [HistoryItem] = []
        var olderItems: [HistoryItem] = []
        
        for item in (chatHistory ?? []) {
            let itemDate = calendar.startOfDay(for: item.dateTime)
            let diffDays = calendar.dateComponents([.day], from: itemDate, to: today).day ?? 0
            
            switch diffDays {
            case 0:
                todayItems.append(item)
            case 1...3:
                previous3DaysItems.append(item)
            case 4...7:
                previous7DaysItems.append(item)
            case 8...30:
                previous30DaysItems.append(item)
            default:
                olderItems.append(item)
            }
        }
        
        var sections: [ArrangedHistoryItem] = []
        
        if !todayItems.isEmpty {
            sections.append(ArrangedHistoryItem(section: "Today", history: todayItems))
        }
        if !previous3DaysItems.isEmpty {
            sections.append(ArrangedHistoryItem(section: "Previous 3 Days", history: previous3DaysItems))
        }
        if !previous7DaysItems.isEmpty {
            sections.append(ArrangedHistoryItem(section: "Previous 7 Days", history: previous7DaysItems))
        }
        if !previous30DaysItems.isEmpty {
            sections.append(ArrangedHistoryItem(section: "Previous 30 Days", history: previous30DaysItems))
        }
        if !olderItems.isEmpty {
            sections.append(ArrangedHistoryItem(section: "Older", history: olderItems))
        }
        
        return sections
    }
    
    func deleteChat(id: String) {
        
        cacheRepository.deleteChat(id: id)
        if let chatIDIndex = chatHistory?.firstIndex(where: { $0.parentChatId == id }) {
            chatHistory?.remove(at: chatIDIndex)
            chatHistoryFiltered = filterAndGroupHistory(chatHistory: chatHistory ?? [])
        }
        
    }
    
    func searchHistory(text: String) {
        
        if text.isEmpty {
            chatHistoryFiltered = filterAndGroupHistory(chatHistory: chatHistory ?? [])
            return
        }
        
        if let chatHistory = chatHistory {
            searchedChatHistory = chatHistory.filter { historyItem in
                historyItem.chats.contains { chat in
                    guard let message = chat.message else { return false }
                    return message.range(of: text, options: .caseInsensitive) != nil
                }
            }
            
            chatHistoryFiltered = filterAndGroupHistory(chatHistory: searchedChatHistory ?? [])
        }
    }
    
    
}
