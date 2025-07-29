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
    let minCharLenForTTS = 20
    private var ttsJobs = [Task<Void, Never>]()
    private let repositoryQueue = DispatchQueue(label: "com.app.repository", qos: .userInitiated)
    let llmService = LLMService()
    let continuousAudioPlayer = ContinuousAudioPlayer()
    let indexToQueueNext = AtomicInteger(value: 1)
    var isFirstAudioGeneratedFlag = false
    let semaphore = DispatchSemaphore(value: 3)
    
    func triggerTTS(text:String,queueNumber:Int) {
        let cleanText = cleanText(text)
        let pcm = try! TTSService.getPCM(input: cleanText)
        continuousAudioPlayer.queueAudio(queueNumber: queueNumber, pcm: pcm)
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
        onFirstAudioGenerated: @escaping () async -> Void,
        onFinished: @escaping () async -> Void,
        onError: @escaping (Error) async -> Void
    ) async {
        isLLMActive = true
        indexToQueueNext.set(1)
        isFirstAudioGeneratedFlag = false
        continuousAudioPlayer.cancelPlaybackAndResetQueue()
        var ttsQueue = ""
        Task(priority: .low) {
            do {
                try await llmService.feedInput(input: textInput)
                
                Task { await triggerFillerAudioTask() }
                
                while true {
                    let outputMap = try await llmService.getNextMap()
                    
                    let str = outputMap["str"]?.data as? String
                    
                    if outputMap["finished"] != nil {
                        await handleFinish(ttsQueue: ttsQueue, latestOutput: str, onFirstAudioGenerated: onFirstAudioGenerated, onFinished: onFinished)
                        onOutputString(str!)
                        break
                    }
                    
                    
                    if str == nil || str!.isEmpty {
                        continue
                    }

                    onOutputString(str!)

                    ttsQueue += str!

                    
                    //TODO: Make this easy to understand
                    if ttsQueue.count < minCharLenForTTS  {
                        continue
                    }
                    
                    // Break off ONE chunk and play it now
                    let (newQueue, ttsCandidate) = breakChunks(ttsQueue1: ttsQueue)
                    ttsQueue = newQueue
                    print("TTS Logs --->>> ttsCandidate: \(ttsCandidate), ttsQueue removedChunk: \(ttsQueue), ttsQueue length: \(ttsQueue.count)")

                    // Send the candidate (not the remainder) to TTS
                    await breakTTSCandidates(ttsQueue1: ttsCandidate, onFirstAudioGenerated: onFirstAudioGenerated)
                                    
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
    
    func handleTTSCandidate(ttsCandidate: String, onFirstAudioGenerated: @escaping () async -> Void) async {
        print("ttsCandidate size: \(ttsCandidate.count)")
        if !isFirstAudioGeneratedFlag {
            print("🎙️ First chunk to TTS: \(ttsCandidate)")
            triggerTTS(text: ttsCandidate, queueNumber: indexToQueueNext.getAndIncrement())
            isFirstAudioGeneratedFlag = true
            await onFirstAudioGenerated()
            
        } else {
            semaphore.wait()
            Task(priority: .userInitiated) {
                defer { semaphore.signal() }
                triggerTTS(text: ttsCandidate, queueNumber: indexToQueueNext.getAndIncrement())
            }
        }

    }
    
    func breakTTSCandidates(ttsQueue1: String, onFirstAudioGenerated: @escaping () async -> Void) async {
        var ttsQueue = ttsQueue1
        while !ttsQueue.isEmpty {
            var chunksOutput = breakChunks(ttsQueue1: ttsQueue)
            ttsQueue = chunksOutput.ttsQueue
            await handleTTSCandidate(ttsCandidate: chunksOutput.ttsCandidate, onFirstAudioGenerated: onFirstAudioGenerated)
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
        //TODO: Insted of random, exclude the first played filler audio
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2s
        if isFirstAudioGeneratedFlag { return }
        continuousAudioPlayer.queueAudio(queueNumber: indexToQueueNext.getAndIncrement(), pcm: GlobalState.fillerAudios.randomElement() ?? [])
        let maxDelay = 5_000_000_000
        var currentDelay = 0
        while !isFirstAudioGeneratedFlag {
            print("TTS Logs --->>> triggerFillerAudioTask currentDelay: \(currentDelay)")
            if currentDelay >= maxDelay {
                if indexToQueueNext.getValue() == 2 {
                    continuousAudioPlayer.queueAudio(queueNumber: indexToQueueNext.getAndIncrement(), pcm: GlobalState.fillerAudios.randomElement() ?? [])
                }
                break
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s
            currentDelay += 1_000_000_000
        }
    }
    
    func getCutOffIndexForTTSQueue(in input: String) -> Int {
        print("getCutOffIndexForTTSQueue input -> \(input), count: \(input.count)")
        let maxCharLen = 200
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

