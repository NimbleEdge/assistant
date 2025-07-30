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
    let minCharLenForTTS = 30
    private var ttsJobs = [Task<Void, Never>]()
    private let repositoryQueue = DispatchQueue(label: "com.app.repository", qos: .userInitiated)
    private let ttsSemaphore = DispatchSemaphore(value: 3)
    private let ttsQueue = DispatchQueue(label: "com.yourapp.tts.concurrentQueue", attributes: .concurrent)
    let llmService = LLMService()
    let continuousAudioPlayer = ContinuousAudioPlayer()
    let indexToQueueNext = AtomicInteger(value: 1)
    var isFirstAudioGeneratedFlag = false
    let semaphore = AsyncSemaphore(value: 3)
    
    func triggerTTS(text:String, queueToPlayAt: Int) {
        let cleanText = cleanText(text)
        let beforeTime = Date().timeIntervalSince1970
        let pcm = try! TTSService.getPCM(input: cleanText)
        let endTime = Date().timeIntervalSince1970
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
        indexToQueueNext.set(1)
        isFirstAudioGeneratedFlag = false
        continuousAudioPlayer.cancelPlaybackAndResetQueue()

        var ttsQueue = ""

        Task(priority: .userInitiated) {
            do {
                try await llmService.feedInput(input: textInput)

                Task { await triggerFillerAudioTask() }

                while true {
                    let outputMap = try await llmService.getNextMap()
                    let str = outputMap["str"]?.data as? String ?? ""

                    if !str.isEmpty {
                        onOutputString(str)
                        ttsQueue += str
                    }

                    // First audio generation – run synchronously for lowest latency
                    if !isFirstAudioGeneratedFlag && ttsQueue.count >= 80 {
                        let (remaining, candidate) = breakChunks(ttsQueue1: ttsQueue)
                        ttsQueue = remaining
                        await breakTTSCandidates(ttsQueue1: candidate,
                                                 queueToPlayAt: indexToQueueNext.getAndIncrement(),
                                                 onFirstAudioGenerated: onFirstAudioGenerated)
                        isFirstAudioGeneratedFlag = true
                        onFirstAudioGenerated()
                    }

                    // Subsequent audio generation – allow concurrent processing
                    while isFirstAudioGeneratedFlag && ttsQueue.count >= minCharLenForTTS {
                        let (remaining, candidate) = breakChunks(ttsQueue1: ttsQueue)
                        ttsQueue = remaining

                        Task {
                            await semaphore.wait()
                            let queueNumber = indexToQueueNext.getAndIncrement()
                            defer {
                                Task { await semaphore.signal() }
                            }
                            await breakTTSCandidates(ttsQueue1: candidate,
                                                     queueToPlayAt: queueNumber,
                                                     onFirstAudioGenerated: onFirstAudioGenerated)
                        }
                    }

                    if outputMap["finished"] != nil {
                        if !ttsQueue.isEmpty {
                            await breakTTSCandidates(ttsQueue1: ttsQueue,
                                                     queueToPlayAt: indexToQueueNext.getAndIncrement(),
                                                     onFirstAudioGenerated: onFirstAudioGenerated)
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
    
    func breakChunks(ttsQueue1: String) -> (ttsQueue: String, ttsCandidate: String) {
        var ttsQueue = ttsQueue1
        let cutoffIndex = getCutOffIndexForTTSQueue(in: ttsQueue)
        let ttsCandidate = ttsQueue.slice(from: 0, to: cutoffIndex)
        ttsQueue.removeChunk(from: 0, to: cutoffIndex)
        return (ttsQueue, ttsCandidate)
    }
    
    func handleFinish(ttsQueue: String, latestOutput: String?, queueToPlayAt: Int, onFirstAudioGenerated: @escaping () async -> Void, onFinished: @escaping () async -> Void) async {
        var ttsQueue: String = ttsQueue
        if let latestOutput = latestOutput {
            ttsQueue.append(contentsOf: latestOutput)
        }
        
        await breakTTSCandidates(ttsQueue1: ttsQueue, queueToPlayAt: queueToPlayAt, onFirstAudioGenerated: onFirstAudioGenerated)
        
        await onFinished()
        isLLMActive = false
    }
    
    func breakTTSCandidates(ttsQueue1: String, queueToPlayAt: Int, onFirstAudioGenerated: @escaping () async -> Void) async {
        var ttsQueue = ttsQueue1
        while !ttsQueue.isEmpty {
            var chunksOutput = breakChunks(ttsQueue1: ttsQueue)
            ttsQueue = chunksOutput.ttsQueue
            triggerTTS(text: chunksOutput.ttsCandidate, queueToPlayAt: queueToPlayAt)
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
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        if isFirstAudioGeneratedFlag { return }
        continuousAudioPlayer.queueAudio(queueNumber: indexToQueueNext.getAndIncrement(), pcm: GlobalState.fillerAudios.uniqueRandomElement(using: &usedFillerIndices).element)
        let maxDelay = 4_000_000_000
        var currentDelay = 0
        
        while !isFirstAudioGeneratedFlag {
            if currentDelay >= maxDelay {
                if indexToQueueNext.getValue() == 2 {
                    continuousAudioPlayer.queueAudio(queueNumber: indexToQueueNext.getAndIncrement(), pcm: GlobalState.fillerAudios.uniqueRandomElement(using: &usedFillerIndices).element)
                }
                break
            }
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
            currentDelay += 100_000_000
        }
    }
    
    func getCutOffIndexForTTSQueue(in input: String) -> Int {
        let maxCharLen = 80
        let limit = min(input.count, maxCharLen)
        let punctuationSet: Set<Character> = [",", "!", "?", ";"]

        let characters = Array(input.prefix(limit))

        for i in (0..<characters.count).reversed() {
            let char = characters[i]
            
            // Check "." only if not part of a number like "4.5"
            if char == "." {
                let isPreviousDigit = i > 0 && characters[i - 1].isNumber
                let isNextDigit = i + 1 < characters.count && characters[i + 1].isNumber
                if !(isPreviousDigit && isNextDigit) {
                    return i
                }
            } else if punctuationSet.contains(char) {
                return i
            }
        }

        return (limit - 1)
    }
  
    func stopLLM() {
        do {
            try LLMService().stopLLM()
        }
        catch{
            print("error stopping LLM")
        }
    }
    
    
    private func isAnyTTSJobActive() -> Bool {
        for job in ttsJobs {
            if !job.isCancelled {
                return true
            }
        }
        return false
    }
    func findCutoffIndexForTTSCandidate(text: String, maxLength: Int) -> Int? {
        if text.count < 12 {
            return nil
        }
        
        let punctuationMarks = [". ", ", ", "? ", "! ", ":", "\n"]
        let searchRangeEnd = min(text.count, maxLength)
        let searchRange = String(text.prefix(searchRangeEnd))
        
        // Find the last occurrence of each punctuation mark
        let indices = punctuationMarks.compactMap { mark in
            searchRange.range(of: mark, options: .backwards)?.lowerBound
        }.map { searchRange.distance(from: searchRange.startIndex, to: $0) }
        
        let lastPunctuation = indices.max()
        
        return lastPunctuation != nil ? lastPunctuation! + 1 : text.count
    }
}

actor AsyncSemaphore {
    private var value: Int
    private var waitQueue: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        if value > 0 {
            value -= 1
        } else {
            await withCheckedContinuation { continuation in
                waitQueue.append(continuation)
            }
        }
    }

    func signal() {
        if !waitQueue.isEmpty {
            let continuation = waitQueue.removeFirst()
            continuation.resume()
        } else {
            value += 1
        }
    }
}
