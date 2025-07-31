/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import AVFoundation
import Combine
import NimbleNetiOS

class ChatRepository {
    
    private var isLLMActive = false
    let minimumCharsForTTS = 35
    let firstChunkMinimumChars = 200
    private var ttsJobs = [Task<Void, Never>]()
    private let repositoryQueue = DispatchQueue(label: "com.app.repository", qos: .userInitiated)
    private let ttsSemaphore = DispatchSemaphore(value: 3)
    private let ttsQueue = DispatchQueue(label: "com.yourapp.tts.concurrentQueue", attributes: .concurrent)
    let llmService = LLMService()
    let continuousAudioPlayer = ContinuousAudioPlayer()
    let nextQueueIndex = AtomicInteger(value: 3) // Start at 3, filler uses 1 and 2
    var hasFirstAudioGenerated = false
    let semaphore = AsyncSemaphore(value: 3)
    
    func generateTTSAudio(text: String, queueToPlayAt: Int) {
        print("[TTS] Starting TTS for queue #\(queueToPlayAt), text: \"\(text.prefix(50))...\"")
        let cleanText = cleanText(text)
        let beforeTime = Date().timeIntervalSince1970
        let pcm = try! TTSService.getPCM(input: cleanText)
        let endTime = Date().timeIntervalSince1970
        print("[TTS] TTS completed for queue #\(queueToPlayAt) in \(endTime - beforeTime)s, queueing audio")
        Task {
            continuousAudioPlayer.enqueueAudio(queueNumber: queueToPlayAt, pcm: pcm)
        }
    }
    
    func processUserTextInput(
        textInput: String,
        onOutputString: @escaping (String) async -> Void,
        onFirstAudioGenerated: @escaping () async -> Void,
        onFinished: @escaping () async -> Void,
        onError: @escaping (Error) async -> Void
    ) async {
        isLLMActive = true
        
        let llmService = LLMService()
        Task(priority: .low) {
            do {
                try await llmService.feedInput(input: textInput)
                while true {
                    let outputMap = try await llmService.getNextMap()
                    
                    guard let tensor = outputMap["str"],
                          let currentOutputString = tensor.data as? String else {
                        continue
                    }
                    
                    await onOutputString(currentOutputString)
                    
                    if outputMap["finished"] != nil {
                        await onFinished()
                        isLLMActive = false
                        break
                    }
                }
            } catch {
                await onError(error)
            }
        }
    }
    func processUserInput(
        textInput: String,
        onOutputString: @escaping (String) -> Void,
        onFirstAudioGenerated: @escaping () -> Void,
        onFinished: @escaping () async -> Void,
        onError: @escaping (Error) async -> Void,
        onAudioFinishedPlaying: (() -> Void)? = nil,
    ) async {
        isLLMActive = true
        nextQueueIndex.set(3) // Reset to 3, filler uses 1 and 2
        hasFirstAudioGenerated = false
        continuousAudioPlayer.stopAndResetPlayback()
        continuousAudioPlayer.startPlaybackLoop()

        var textQueue = ""

        Task(priority: .userInitiated) {
            do {
                try await llmService.feedInput(input: textInput)

                Task { await playFillerAudio() }

                while true {
                    let outputMap = try await llmService.getNextMap()
                    let str = outputMap["str"]?.data as? String ?? ""

                    if !str.isEmpty {
                        if hasFirstAudioGenerated{
                            onOutputString(str)
                        }
                        textQueue += str
                    }

                    // First audio generation – run synchronously for lowest latency
                    if !hasFirstAudioGenerated && textQueue.count >= firstChunkMinimumChars {
                        print("[LLM] Creating FIRST chunk (longer) from \(textQueue.count) chars (threshold: \(firstChunkMinimumChars))")
                        let (remainingText, textChunk) = extractTextChunk(queuedText: textQueue, isFirstChunk: true)
                        let prev = textQueue
                        textQueue = remainingText
                        let firstAudioQueue = nextQueueIndex.getAndIncrement()
                        print("[LLM] First LLM audio assigned queue #\(firstAudioQueue), chunk size: \(textChunk.count) chars")
                        generateTTSAudio(text: textChunk, queueToPlayAt: firstAudioQueue)
                        hasFirstAudioGenerated = true
                        onFirstAudioGenerated()
                        onOutputString(prev)
                    }

                    // Subsequent audio generation – allow concurrent processing
                    while hasFirstAudioGenerated && textQueue.count >= minimumCharsForTTS {
                        print("[LLM] Creating SUBSEQUENT chunk (smaller) from \(textQueue.count) chars (threshold: \(minimumCharsForTTS))")
                        let (remainingText, textChunk) = extractTextChunk(queuedText: textQueue, isFirstChunk: false)
                        textQueue = remainingText

                        Task {
                            await semaphore.wait()
                            let queueNumber = nextQueueIndex.getAndIncrement()
                            print("[LLM] Subsequent chunk assigned queue #\(queueNumber), chunk size: \(textChunk.count) chars")
                            defer {
                                Task { await semaphore.signal() }
                            }
                            generateTTSAudio(text: textChunk, queueToPlayAt: queueNumber)
                        }
                    }

                    if outputMap["finished"] != nil {
                        // Process final chunk using same semaphore logic
                        if !textQueue.isEmpty {
                            Task {
                                await semaphore.wait()
                                let finalQueue = nextQueueIndex.getAndIncrement()
                                defer {
                                    Task { await semaphore.signal() }
                                }
                                generateTTSAudio(text: textQueue, queueToPlayAt: finalQueue)
                                //TODO: Not working fine
                                continuousAudioPlayer.onFinshedPlaying = { queueNumber in
                                    if finalQueue == queueNumber { onAudioFinishedPlaying?() }
                                }
                            }
                        }
                        onOutputString(textQueue)
                        await onFinished()
                        isLLMActive = false
                        break
                    }

                    try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms throttle
                }
            } catch {
                await onError(error)
            }
        }
    }
    
    func extractTextChunk(queuedText: String, isFirstChunk: Bool = false) -> (remainingText: String, textChunk: String) {
        var textQueue = queuedText
        let cutoffIndex = getCutOffIndexForTTSQueue(in: textQueue, isFirstChunk: isFirstChunk)
        let textChunk = textQueue.slice(from: 0, to: cutoffIndex)
        textQueue.removeChunk(from: 0, to: cutoffIndex)
        return (textQueue, textChunk)
    }
    
    func processTextIntoChunks(queuedText: String, startingQueueNumber: Int, onFirstAudioGenerated: @escaping () async -> Void) async {
        let text = queuedText.trimmingCharacters(in: .whitespacesAndNewlines)

        // Break down large text into smaller chunks
        var remainingText = text
        var currentQueueNumber = startingQueueNumber
        
        while !remainingText.isEmpty && remainingText.count > minimumCharsForTTS {
            let cutoffIndex = getCutOffIndexForTTSQueue(in: remainingText, isFirstChunk: false)
            let chunk = remainingText.slice(from: 0, to: cutoffIndex)
            remainingText.removeChunk(from: 0, to: cutoffIndex)
            
            if !chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                generateTTSAudio(text: chunk, queueToPlayAt: currentQueueNumber)
                currentQueueNumber = nextQueueIndex.getAndIncrement()
            }
        }
        
        // Handle any remaining text
        if !remainingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            generateTTSAudio(text: remainingText, queueToPlayAt: currentQueueNumber)
        }
    }
    
    private func cleanText(_ text: String) -> String {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[\"*#]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: "…")
        return cleaned
    }

    
    func playFillerAudio() async {
        var usedFillerIndices: Set<Int> = []
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 1s
        if hasFirstAudioGenerated { return }
        
        // Hardcode first filler to queue 1
        print("[Filler] Playing first filler audio at queue #1")
        continuousAudioPlayer.enqueueAudio(queueNumber: 1, pcm: GlobalState.fillerAudios.uniqueRandomElement(using: &usedFillerIndices).element)
        
        // Wait 5 seconds and decide if second filler should play
        let maxDelay = 6_000_000_000
        var currentDelay = 0
        
        while !hasFirstAudioGenerated && currentDelay < maxDelay {
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            currentDelay += 50_000_000
        }
        
        // Only queue second filler if first audio is still not ready after max delay
        if !hasFirstAudioGenerated {
            print("[Filler] Max delay reached, playing second filler at queue #2")
            continuousAudioPlayer.enqueueAudio(queueNumber: 2, pcm: GlobalState.fillerAudios.uniqueRandomElement(using: &usedFillerIndices).element)
        } else {
            print("[Filler] Second filler skipped - first audio ready (skip logic now in playback loop)")
        }
    }
    
  
    func stopLLM() {
        do {
            try LLMService().stopLLM()
        }
        catch{
            print("error stopping LLM")
        }
    }

}
