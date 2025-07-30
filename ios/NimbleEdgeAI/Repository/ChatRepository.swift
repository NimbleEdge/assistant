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
    let minCharLenForTTS = 35
    let firstChunkMinThreshold = 200
    private var ttsJobs = [Task<Void, Never>]()
    private let repositoryQueue = DispatchQueue(label: "com.app.repository", qos: .userInitiated)
    private let ttsSemaphore = DispatchSemaphore(value: 3)
    private let ttsQueue = DispatchQueue(label: "com.yourapp.tts.concurrentQueue", attributes: .concurrent)
    let llmService = LLMService()
    let continuousAudioPlayer = ContinuousAudioPlayer()
    let indexToQueueNext = AtomicInteger(value: 3) // Start at 3, filler uses 1 and 2
    var isFirstAudioGeneratedFlag = false
    let semaphore = AsyncSemaphore(value: 3)
    
    func triggerTTS(text:String, queueToPlayAt: Int) {
        print("[TTS] Starting TTS for queue #\(queueToPlayAt), text: \"\(text.prefix(50))...\"")
        let cleanText = cleanText(text)
        let beforeTime = Date().timeIntervalSince1970
        let pcm = try! TTSService.getPCM(input: cleanText)
        let endTime = Date().timeIntervalSince1970
        print("[TTS] TTS completed for queue #\(queueToPlayAt) in \(endTime - beforeTime)s, queueing audio")
        Task {
            continuousAudioPlayer.queueAudio(queueNumber: queueToPlayAt, pcm: pcm)
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
        onError: @escaping (Error) async -> Void
    ) async {
        isLLMActive = true
        indexToQueueNext.set(3) // Reset to 3, filler uses 1 and 2
        isFirstAudioGeneratedFlag = false
        continuousAudioPlayer.cancelPlaybackAndResetQueue()
        continuousAudioPlayer.startContinuousPlaybackLoop()

        var ttsQueue = ""

        Task(priority: .userInitiated) {
            do {
                try await llmService.feedInput(input: textInput)

                Task { await triggerFillerAudioTask() }

                while true {
                    let outputMap = try await llmService.getNextMap()
                    let str = outputMap["str"]?.data as? String ?? ""

                    if !str.isEmpty {
                        if isFirstAudioGeneratedFlag{
                            onOutputString(str)
                        }
                        ttsQueue += str
                    }

                    // First audio generation – run synchronously for lowest latency
                    if !isFirstAudioGeneratedFlag && ttsQueue.count >= firstChunkMinThreshold {
                        print("[LLM] Creating FIRST chunk (longer) from \(ttsQueue.count) chars (threshold: \(firstChunkMinThreshold))")
                        let (remaining, candidate) = breakChunks(ttsQueue1: ttsQueue, isFirstChunk: true)
                        let prev = ttsQueue
                        ttsQueue = remaining
                        let firstAudioQueue = indexToQueueNext.getAndIncrement()
                        print("[LLM] First LLM audio assigned queue #\(firstAudioQueue), chunk size: \(candidate.count) chars")
                        triggerTTS(text: candidate, queueToPlayAt: firstAudioQueue)
                        isFirstAudioGeneratedFlag = true
                        onFirstAudioGenerated()
                        onOutputString(prev)
                    }

                    // Subsequent audio generation – allow concurrent processing
                    while isFirstAudioGeneratedFlag && ttsQueue.count >= minCharLenForTTS {
                        print("[LLM] Creating SUBSEQUENT chunk (smaller) from \(ttsQueue.count) chars (threshold: \(minCharLenForTTS))")
                        let (remaining, candidate) = breakChunks(ttsQueue1: ttsQueue, isFirstChunk: false)
                        ttsQueue = remaining

                        Task {
                            await semaphore.wait()
                            let queueNumber = indexToQueueNext.getAndIncrement()
                            print("[LLM] Subsequent chunk assigned queue #\(queueNumber), chunk size: \(candidate.count) chars")
                            defer {
                                Task { await semaphore.signal() }
                            }
                            triggerTTS(text: candidate, queueToPlayAt: queueNumber)
                        }
                    }

                    if outputMap["finished"] != nil {
                        // Process final chunk using same semaphore logic
                        if !ttsQueue.isEmpty {
                            Task {
                                await semaphore.wait()
                                let finalQueue = indexToQueueNext.getAndIncrement()
                                defer {
                                    Task { await semaphore.signal() }
                                }
                                triggerTTS(text: ttsQueue, queueToPlayAt: finalQueue)
                            }
                        }
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
    
    func breakChunks(ttsQueue1: String, isFirstChunk: Bool = false) -> (ttsQueue: String, ttsCandidate: String) {
        var ttsQueue = ttsQueue1
        let cutoffIndex = getCutOffIndexForTTSQueue(in: ttsQueue, isFirstChunk: isFirstChunk)
        let ttsCandidate = ttsQueue.slice(from: 0, to: cutoffIndex)
        ttsQueue.removeChunk(from: 0, to: cutoffIndex)
        return (ttsQueue, ttsCandidate)
    }
    
    func breakTTSCandidates(ttsQueue1: String, startingQueueNumber: Int, onFirstAudioGenerated: @escaping () async -> Void) async {
        let text = ttsQueue1.trimmingCharacters(in: .whitespacesAndNewlines)

        // Break down large text into smaller chunks
        var remainingText = text
        var currentQueueNumber = startingQueueNumber
        
        while !remainingText.isEmpty && remainingText.count > minCharLenForTTS {
            let cutoffIndex = getCutOffIndexForTTSQueue(in: remainingText, isFirstChunk: false)
            let chunk = remainingText.slice(from: 0, to: cutoffIndex)
            remainingText.removeChunk(from: 0, to: cutoffIndex)
            
            if !chunk.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                triggerTTS(text: chunk, queueToPlayAt: currentQueueNumber)
                currentQueueNumber = indexToQueueNext.getAndIncrement()
            }
        }
        
        // Handle any remaining text
        if !remainingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            triggerTTS(text: remainingText, queueToPlayAt: currentQueueNumber)
        }
    }
    
    private func cleanText(_ text: String) -> String {
        let cleaned = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[\"*#]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: "…")
        return cleaned
    }

    
    func triggerFillerAudioTask() async {
        var usedFillerIndices: Set<Int> = []
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 1s
        if isFirstAudioGeneratedFlag { return }
        
        // Hardcode first filler to queue 1
        print("[Filler] Playing first filler audio at queue #1")
        continuousAudioPlayer.queueAudio(queueNumber: 1, pcm: GlobalState.fillerAudios.uniqueRandomElement(using: &usedFillerIndices).element)
        
        // Wait 5 seconds and decide if second filler should play
        let maxDelay = 6_000_000_000
        var currentDelay = 0
        
        while !isFirstAudioGeneratedFlag && currentDelay < maxDelay {
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            currentDelay += 50_000_000
        }
        
        // Only queue second filler if first audio is still not ready after max delay
        if !isFirstAudioGeneratedFlag {
            print("[Filler] Max delay reached, playing second filler at queue #2")
            continuousAudioPlayer.queueAudio(queueNumber: 2, pcm: GlobalState.fillerAudios.uniqueRandomElement(using: &usedFillerIndices).element)
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
