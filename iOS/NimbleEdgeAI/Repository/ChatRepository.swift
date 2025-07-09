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
    let MAX_CHAR_LEN = 200
    private var ttsJobs = [Task<Void, Never>]()
    private let repositoryQueue = DispatchQueue(label: "com.app.repository", qos: .userInitiated)
    
    func triggerTTS(text:String,queueNumber:Int) {
        let pcm = TTSService.getPCM(input: text)
        ContinuousAudioPlayer.shared.queueAudio(queueNumber: queueNumber, pcm: pcm)
    }
    
    
    func processUserTextInput(
        textInput: String,
        onOutputString: @escaping (String) async -> Void,
        onFirstAudioGenerated: @escaping () async -> Void,
        onFinished: @escaping () async -> Void,
        onError: @escaping (Error) async -> Void
    ) async {
        isLLMActive = true
        
        let indexToQueueNext = AtomicInteger(value: 1)
        let llmService = LLMService()
        let semaphore = DispatchSemaphore(value: 3)
        var ttsQueue = ""
        var isFirstAudioGenerated = false
        Task(priority: .low) {
            do {
                try await llmService.feedInput(input: textInput)
                while true {
                    let outputMap = try await llmService.getNextMap()
                    
                    
                    guard let tensor = outputMap["str"] as? NimbleNetTensor,
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
        onOutputString: @escaping (String) async -> Void,
        onFirstAudioGenerated: @escaping () async -> Void,
        onFinished: @escaping () async -> Void,
        onError: @escaping (Error) async -> Void
    ) async {
        isLLMActive = true
        
        let llmService = LLMService()
        let semaphore = DispatchSemaphore(value: 3)
        // let indexToQueueNext = AtomicInteger(value: 1)
        let resetQueueNumber = ContinuousAudioPlayer.shared.cancelPlaybackAndResetQueue()
        let indexToQueueNext = AtomicInteger(value: resetQueueNumber)
        var isFirstAudioGeneratedFlag = false
        var ttsQueue = ""
        var finalqueue = ""
        Task(priority: .low) {
            do {
                try await llmService.feedInput(input: textInput)
                while true {
                    let outputMap = try await llmService.getNextMap()
                    
                    guard let tensor = outputMap["str"] as? NimbleNetTensor,
                          let currentOutputString = tensor.data as? String else {
                        continue
                    }
                    
                    await onOutputString(currentOutputString)
                    
                    finalqueue += currentOutputString
                    ttsQueue += currentOutputString
                    
                    if ttsQueue.count < 2 * MAX_CHAR_LEN && outputMap["finished"] == nil {
                        continue
                    }
                    
                    var textChunks = chunkText(ttsQueue)
                    
                    let totalProcessed = textChunks.reduce(0) { $0 + $1.count }
                    if totalProcessed < ttsQueue.count {
                        let startIdx = ttsQueue.index(ttsQueue.startIndex, offsetBy: totalProcessed)
                        ttsQueue = String(ttsQueue[startIdx...])
                    } else {
                        ttsQueue = ""
                    }
                    
                    if outputMap["finished"] != nil && !ttsQueue.isEmpty {
                        let remainingChunks = chunkText(ttsQueue)
                        textChunks.append(contentsOf: remainingChunks)
                        ttsQueue = ""
                    }
                    
                    if !isFirstAudioGeneratedFlag {
                        if let firstChunk = textChunks.first, !firstChunk.isEmpty {
                            print("🎙️ First chunk to TTS: \(firstChunk)")
                            triggerTTS(text: firstChunk, queueNumber: indexToQueueNext.getAndIncrement())
                            isFirstAudioGeneratedFlag = true
                            await onFirstAudioGenerated()
                        }
                        
                        for chunk in textChunks.dropFirst() where !chunk.isEmpty {
                            semaphore.wait()
                            Task(priority: .userInitiated) {
                                defer { semaphore.signal() }
                                do {
                                    print("🎙️ TTS chunk (first batch): \(chunk)")
                                    triggerTTS(text: chunk, queueNumber: indexToQueueNext.getAndIncrement())
                                } catch {
                                    await onError(error)
                                }
                            }
                        }
                    } else {
                        for chunk in textChunks where !chunk.isEmpty {
                            semaphore.wait()
                            Task(priority: .userInitiated) {
                                defer { semaphore.signal() }
                                do {
                                    triggerTTS(text: chunk, queueNumber: indexToQueueNext.getAndIncrement())
                                } catch {
                                    await onError(error)
                                }
                            }
                        }
                    }
                    
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
    
    func chunkText(_ text: String) -> [String] {
        
        let cleanedText = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[\"*#]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n", with: "…")
        
        
        let regexPattern = #"(\S.*?(?:[!?:]|\. (?!\d)))(?=\s+|$)"#
        guard let regex = try? NSRegularExpression(pattern: regexPattern, options: []) else {
            return []
        }
        
        let range = NSRange(location: 0, length: cleanedText.utf16.count)
        let matches = regex.matches(in: cleanedText, options: [], range: range)
        
        var inputChunks = matches.map {
            if let range = Range($0.range, in: cleanedText) {
                return String(cleanedText[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return ""
        }.filter { !$0.isEmpty }
        
        inputChunks = inputChunks.flatMap { chunkSentence($0) }
        
        inputChunks = mergeChunks(inputChunks)
        
        return inputChunks
    }
    
    
    func chunkSentence(_ input: String) -> [String] {
        var chunkedList: [String] = []
        
        if input.count < MAX_CHAR_LEN {
            chunkedList.append(input)
        } else if input.contains(",") {
            let commaSplits = input.split(separator: ",", maxSplits: 2, omittingEmptySubsequences: false).map { String($0) }
            var splitsMerged: [String] = [""]
            var curIdx = 0
            
            for (idx, split) in commaSplits.enumerated() {
                if splitsMerged[curIdx].count + split.count < MAX_CHAR_LEN {
                    if idx > 0 { splitsMerged[curIdx] += "," }
                    splitsMerged[curIdx] += split
                } else if split.count > MAX_CHAR_LEN {
                    let spaceSplits = split
                        .split(separator: " ")
                        .chunked(into: 6)
                        .map { $0.joined(separator: " ") }
                    
                    splitsMerged[curIdx] += ","
                    
                    var spaceIndex = 0
                    while spaceIndex < spaceSplits.count {
                        let s = spaceSplits[spaceIndex]
                        if splitsMerged[curIdx].count + s.count < MAX_CHAR_LEN {
                            splitsMerged[curIdx] += s
                            spaceIndex += 1
                        } else {
                            splitsMerged.append(s)
                            curIdx += 1
                            spaceIndex += 1
                        }
                    }
                } else {
                    splitsMerged.append(split)
                    curIdx += 1
                }
            }
            
            chunkedList.append(contentsOf: splitsMerged)
        } else {
            let spaceChunks = input
                .split(separator: " ")
                .chunked(into: 6)
                .map { $0.joined(separator: " ") }
            
            chunkedList.append(contentsOf: spaceChunks)
        }
        
        return chunkedList
    }
    
    func mergeChunks(_ chunks: [String]) -> [String] {
        var mergedChunks: [String] = [""]
        var curIdx = 0
        
        for (idx, text) in chunks.enumerated() {
            if text.count + mergedChunks[curIdx].count < MAX_CHAR_LEN / 2 {
                mergedChunks[curIdx] += (idx == 0 ? "" : " ") + text
            } else {
                mergedChunks.append(text)
                curIdx += 1
            }
        }
        
        return mergedChunks
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
    
    func playFillerAudio() {
        ContinuousAudioPlayer.shared.expectedFillerQueue = 1
        Task {
            try? await Task.sleep(nanoseconds: 100_000_000)
            ContinuousAudioPlayer.shared.queueAudio(queueNumber: 1, pcm: GlobalState.fillerAudios.randomElement() ?? [])
            try? await Task.sleep(nanoseconds: 700_000_000)
            ContinuousAudioPlayer.shared.queueAudio(queueNumber: 2, pcm: GlobalState.fillerAudios.randomElement() ?? [])
        }
    }
}

