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
    var isFirstAudioGeneratedFlag = false {
        didSet {
            print("didSet isFirstAudioGeneratedFlag: \(isFirstAudioGeneratedFlag)")
        }
    }
    let semaphore = AsyncSemaphore(value: 3)
    
    func triggerTTS(text:String) {
        let cleanText = cleanText(text)
        let beforeTime = Date().timeIntervalSince1970
        print("cleanText \(cleanText.count)")
        let pcm = try! TTSService.getPCM(input: cleanText)
        let endTime = Date().timeIntervalSince1970
        print("Difference in PCM genration time: \(endTime - beforeTime)")
        let queueNumber = indexToQueueNext.getAndIncrement()
        print("triggerTTS audio queueNumber: \(queueNumber), text: \(cleanText), time: \(Date().timeIntervalSince1970)")
        Task {
            continuousAudioPlayer.queueAudio(queueNumber: queueNumber, pcm: pcm)
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
                
                var cmt = 0
                while true {
                    let outputMap = try await llmService.getNextMap()
                    
                    let str = outputMap["str"]?.data as? String
                    
                    if outputMap["finished"] != nil {
                        Task {
                            await handleFinish(ttsQueue: ttsQueue, latestOutput: str, onFirstAudioGenerated: onFirstAudioGenerated, onFinished: onFinished)
                        }
                        onOutputString(str!)
                        break
                    }
                    
                    if str == nil || str!.isEmpty {
                        continue
                    }

                    onOutputString(str!)
                    
                    ttsQueue += str!
                    if ttsQueue.count < minCharLenForTTS  {
                        continue
                    }
                    
                    if !isFirstAudioGeneratedFlag {
                        // Break off ONE chunk and play it now
                        let (newQueue, ttsCandidate) = breakChunks(ttsQueue1: ttsQueue)
                        ttsQueue = newQueue
                        
                        // Send the candidate (not the remainder) to TTS
                        await breakTTSCandidates(ttsQueue1: ttsCandidate, onFirstAudioGenerated: onFirstAudioGenerated)
                        isFirstAudioGeneratedFlag = true
                        onFirstAudioGenerated()
                    } else {
                        print("cmt: \(cmt)")
                        Task {
                            await semaphore.wait()
                            cmt += 1
                            defer { Task {
                                await semaphore.signal()
                                cmt -= 1
                            } }
                            
                            // Break off ONE chunk and play it now
                            let (newQueue, ttsCandidate) = breakChunks(ttsQueue1: ttsQueue)
                            ttsQueue = newQueue
                            
                            // Send the candidate (not the remainder) to TTS
                            await breakTTSCandidates(ttsQueue1: ttsCandidate, onFirstAudioGenerated: onFirstAudioGenerated)
                        }
                    }
                                    
                    try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                }
            } catch {
                await onError(error)
            }
        }
    }
    
    func breakChunks(ttsQueue1: String) -> (ttsQueue: String, ttsCandidate: String) {
        print("old ttsQueue: \(ttsQueue1.count)")
        var ttsQueue = ttsQueue1
        let cutoffIndex = getCutOffIndexForTTSQueue(in: ttsQueue)
        let ttsCandidate = ttsQueue.slice(from: 0, to: cutoffIndex)
        ttsQueue.removeChunk(from: 0, to: cutoffIndex)
        print("updated ttsQueue: \(ttsQueue.count)")
        print("ttsCandidate count: \(ttsCandidate.count)")
        return (ttsQueue, ttsCandidate)
    }
    
    func handleFinish(ttsQueue: String, latestOutput: String?, onFirstAudioGenerated: @escaping () async -> Void, onFinished: @escaping () async -> Void,) async {
        var ttsQueue: String = ttsQueue
        if let latestOutput = latestOutput {
            ttsQueue.append(contentsOf: latestOutput)
        }
        print("Last Candidate Called: \(ttsQueue.count)")
        
        await breakTTSCandidates(ttsQueue1: ttsQueue, onFirstAudioGenerated: onFirstAudioGenerated)
        
        await onFinished()
        isLLMActive = false
    }
    
    func breakTTSCandidates(ttsQueue1: String, onFirstAudioGenerated: @escaping () async -> Void) async {
        var ttsQueue = ttsQueue1
        while !ttsQueue.isEmpty {
            var chunksOutput = breakChunks(ttsQueue1: ttsQueue)
            ttsQueue = chunksOutput.ttsQueue
            triggerTTS(text: chunksOutput.ttsCandidate)
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
        print("getCutOffIndexForTTSQueue input -> \(input), count: \(input.count)")
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
                    print("Last punctuation index: \(i)")
                    return i
                }
            } else if punctuationSet.contains(char) {
                print("Last punctuation index: \(i)")
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
