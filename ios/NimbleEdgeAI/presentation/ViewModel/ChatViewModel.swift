/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import SwiftUI
import Combine
import NimbleNetiOS

class ChatViewModel: ObservableObject {
    private let chatRepository: ChatRepository = ChatRepository()
    private let cacheRepository: CacheRepository = CacheRepository()
    @Published var outputStream: String?
    @Published var currentTPS: Float?
    @Published var chatHistory: [ChatMessage] = []
    @Published var currentMessageLoading: Bool = true
    var currentChatId: String?
    var isVoiceMode: Bool?
    
    // Voice overlay state
    @Published var isOverlayVisible: Bool = false
    @Published var isInterruptButtonVisible:Bool = false

    
    @Published var isLLMActive: Bool = false
    @Published var isASRActive: Bool = false
    @Published var isUserSpeaking: Bool = false
    @Published var isLLMSpeaking: Bool = false
    
    // For voice recognition text handling
    @Published var spokenText: String = ""
    @Published var persistedRecognizedText: String = ""
    @Published var volumeState: Float = 0.0
    
    private var chattingTask: Task<Void, Never>? = nil
    private let addToChatMessageLock = NSLock()
    
    var onNewMessageAdded: ((_ message: ChatMessage) -> Void)?
    var onChatHistoryUpdated: ((_ chatHistory: [ChatMessage]) -> Void)?
    var onOutputStreamUpdated: ((_ outputStream: String?) -> Void)?
    var onLLMActive: ((_ isActive: Bool) -> Void)?
    
    private var cancellables = Set<AnyCancellable>()
    
    func setOverlayVisibility(_ visible: Bool) {
        self.isOverlayVisible = visible
    }
    func cancelTTS() {
        chatRepository.continuousAudioPlayer.stopAndResetPlayback()
        isLLMSpeaking = false
    }
    
    func set(chatID: String?) {
        if let chatID = chatID{
            self.currentChatId = chatID
        } else {
            createChatID()
        }
        retriveChatHistory()
    }
    
    func retriveChatHistory() {
        DispatchQueue.global().async(execute: { [weak self] in
            let chatHistory = self?.cacheRepository.retrieveChat(id: self?.currentChatId ?? "")?.messages ?? []
            DispatchQueue.main.async {
                self?.chatHistory = chatHistory
                self?.onChatHistoryUpdated?(chatHistory)
            }
        })
    }

    func cancelLLM(){
        chattingTask?.cancel()
    }
    
    func interruptResponse(){
        self.cancelLLM()
        self.cancelCurrentLLM()
        self.saveChatToRepository()
    }

    func createChatID() {
        currentChatId = UUID().uuidString
    }
    
    
    func cancelCurrentLLM() {
        if isLLMActive {
            if let outputStream = outputStream, !outputStream.isEmpty {
                self.saveChatToRepository()
            }
            DispatchQueue.global().async { [weak self] in
                self?.chatRepository.stopLLM()
            }
            
            isLLMActive = false
            DispatchQueue.main.async { [weak self] in
                self?.outputStream = nil
            }
            
        }
    }
    
    func clearContextAndStartNewChat(){
        
    }
    
    func passTextInputToLLM(_ textInput: String) {
        
        if(textInput == "") { return }
        
        var index = AtomicInteger(value: 1)
        DispatchQueue.main.async {
            self.currentMessageLoading = true
            self.outputStream = ""
            self.isLLMActive = true
            self.onLLMActive?(self.isLLMActive)
            let chatMessage = ChatMessage(message: "", isUserMessage: false, timestamp: Date(), tps: 0)
            self.chatHistory.append(chatMessage)
            self.onNewMessageAdded?(self.chatHistory.last!)
        }
        
        if isOverlayVisible {
            DispatchQueue.main.async { self.isLLMSpeaking = true }
            chattingTask = Task(priority: .low) {
                do {
                    await chatRepository.processUserInput(
                        textInput: textInput,
                        onOutputString: { [weak self] output in
                            if output.isEmpty { return }
                            DispatchQueue.main.async {
                                guard let self, self.isLLMActive else { return }
                                
                                
                                if let outputStream = self.outputStream, outputStream.isEmpty {
                                    //triming extra spcaes
                                    let newOutputStream = ((self.outputStream ?? "") + output)
                                    if let range = newOutputStream.range(of: "\\S", options: .regularExpression) {
                                        self.outputStream = newOutputStream[range.lowerBound...].description
                                        self.chatHistory[self.chatHistory.count - 1].message = self.outputStream
                                        self.onOutputStreamUpdated?(self.outputStream)
                                    }
                                } else {
                                    self.outputStream = (self.outputStream ?? "") + output
                                    self.chatHistory[self.chatHistory.count - 1].message = self.outputStream
                                    self.onOutputStreamUpdated?(self.outputStream)
                                }
                                
                            }
                        },
                        onFirstAudioGenerated: { [weak self] in
                            DispatchQueue.main.async {
                                self?.currentMessageLoading = false
                            }
                        },
                        onFinished: { [weak self] in
                            guard let self = self else { return }
                            
                            self.cancelLLM()
                            DispatchQueue.main.async {
                                self.cancelCurrentLLM()
                                self.isInterruptButtonVisible = false
                                self.isASRActive = true
                            }
                        },
                        onError: { [weak self] error in
                            print("LLM processing error: \(error)")
                            DispatchQueue.main.async {
                                self?.isLLMActive = false
                            }
                        },
                        onAudioFinishedPlaying: { [weak self] in
                            DispatchQueue.main.async {
                                self?.isLLMSpeaking = false
                            }
                            
                        }
                    )
                }
            }
        }
        else{
            chattingTask = Task(priority: .low) {
                do {
                    await chatRepository.processUserInput(
                        textInput: textInput,
                        onOutputString: { [weak self] output in
                            if output.isEmpty { return }
                            DispatchQueue.main.async {
                                guard let self else { return }
                                
                                if let outputStream = self.outputStream, outputStream.isEmpty {
                                    //triming extra spcaes
                                    let newOutputStream = ((self.outputStream ?? "") + output)
                                    if let range = newOutputStream.range(of: "\\S", options: .regularExpression) {
                                        self.outputStream = newOutputStream[range.lowerBound...].description
                                        self.chatHistory[self.chatHistory.count - 1].message = self.outputStream
                                        self.onOutputStreamUpdated?(self.outputStream)
                                    }
                                } else {
                                    self.outputStream = (self.outputStream ?? "") + output
                                    self.chatHistory[self.chatHistory.count - 1].message = self.outputStream
                                    self.onOutputStreamUpdated?(self.outputStream)
                                }

                            }
                        },
                        onFirstAudioGenerated: { [weak self] in
                            DispatchQueue.main.async {
                                self?.currentMessageLoading = false
                            }
                        },
                        onFinished: { [weak self] in
                            guard let self = self else { return }
                            
                            self.cancelLLM()
                            DispatchQueue.main.async {
                                self.cancelCurrentLLM()
                                self.isInterruptButtonVisible = false
                            }
                        },
                        onError: { [weak self] error in
                            print("LLM processing error: \(error)")
                            DispatchQueue.main.async {
                                self?.isLLMActive = false
                            }
                        }
                    )
                }
            }
        }

    }
    
    func addNewMessageToChatHistory(message: String, isUserInput: Bool) {
        
        if message.isEmpty { return }
        
        let newMessage = ChatMessage(
            message: message,
            isUserMessage: isUserInput,
            timestamp: Date(), tps: currentTPS ?? 0
        )
        
        chatHistory.append(newMessage)
        onNewMessageAdded?(newMessage)
        currentTPS = nil
        
        saveChatToRepository()
    }
    
    func saveChatToRepository() {
        guard let chatId = currentChatId else { return }
        let chat = Chat(messages: chatHistory, id: chatId)
        
        Task {
             cacheRepository.cacheChat(chat)
        }
    }
    
    func reset() {
        do {
            let res = NimbleNetApi.runMethod(methodName: "clear_prompt", inputs: [:])
            // saving current chat
            saveChatToRepository()
            resetUpdateCallBacks()
            cancelCurrentLLM()
            DispatchQueue.main.async { [weak self] in
                self?.chatHistory.removeAll()
            }
            createChatID()
            
        } catch {
            print("Error clearing chat: \(error.localizedMessage)")
        }
    }

    
    func resetUpdateCallBacks() {
        onNewMessageAdded = nil
        onChatHistoryUpdated = nil
        onOutputStreamUpdated = nil
        onLLMActive = nil
    }
    
    func createNewChat() {
        currentChatId = UUID().uuidString
    }
    
    deinit {
        cancelCurrentLLM()
        cancellables.forEach { $0.cancel() }
    }
}
