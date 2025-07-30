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
    let minCharLenForTTS = 35  // Reduced from 50 for quicker subsequent chunks
    let firstChunkMinThreshold = 200  // Increased from 120 for longer first chunk
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
    
    func getCutOffIndexForTTSQueue(in input: String, isFirstChunk: Bool = false) -> Int {
        // Different limits for first vs subsequent chunks
        let maxCharLen = isFirstChunk ? 200 : 120  // Longer first chunk, shorter subsequent
        let minCharLen = isFirstChunk ? 120 : 35   // Higher minimum for first, lower for subsequent
        let limit = min(input.count, maxCharLen)
        
        if limit <= minCharLen {
            return limit - 1
        }
        
        let characters = Array(input.prefix(limit))
        let text = String(characters)
        
        // Search from ideal position (75% of max length) backwards for best break
        let idealPosition = min(Int(Double(maxCharLen) * 0.75), limit - 1)
        
        // Safety check: ensure idealPosition is not less than minCharLen to avoid invalid ranges
        let safeIdealPosition = max(idealPosition, minCharLen)
        
        // PRIORITY 0: Structured content breaks - section headers, list boundaries
        // Look for markdown headers like "**Blend 1:**" or "**Section:**"
        let headerPattern = "\\*\\*[^*]+\\*\\*"
        if let regex = try? NSRegularExpression(pattern: headerPattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            for match in matches.reversed() {
                let endIndex = match.range.location + match.range.length
                if endIndex >= minCharLen && endIndex <= safeIdealPosition {
                    // Check if there's a line break or colon after the header
                    if endIndex < text.count {
                        let nextChar = text[text.index(text.startIndex, offsetBy: endIndex)]
                        if nextChar == "\n" || nextChar == ":" {
                            return endIndex + 1
                        }
                    }
                    return endIndex
                }
            }
        }
        
        // PRIORITY 0.5: Double line breaks (paragraph/section separators)
        if let range = text.range(of: "\n\n", options: [.backwards]) {
            let index = text.distance(from: text.startIndex, to: range.upperBound)
            if index >= minCharLen && index <= safeIdealPosition {
                return index
            }
        }
        
        // PRIORITY 0.7: End of bullet point lists (before section headers)
        // Look for pattern: "* item\n\n**" or "* item\n**"
        let bulletEndPattern = "\\*[^\n]+\n(?:\n)?\\*\\*"
        if let regex = try? NSRegularExpression(pattern: bulletEndPattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            for match in matches.reversed() {
                let breakIndex = match.range.location + match.range.length - 2 // Before the "**"
                if breakIndex >= minCharLen && breakIndex <= safeIdealPosition {
                    return breakIndex
                }
            }
        }
        
        // PRIORITY 0.8: Single line breaks before section headers
        if let range = text.range(of: "\n**", options: [.backwards]) {
            let index = text.distance(from: text.startIndex, to: range.lowerBound) + 1
            if index >= minCharLen && index <= safeIdealPosition {
                return index
            }
        }
        
        // PRIORITY 1: Strong sentence breaks (period, exclamation, question)
        let strongBreaks: Set<Character> = [".", "!", "?"]
        
        // PRIORITY 2: Clause breaks (comma, semicolon, colon)
        let clauseBreaks: Set<Character> = [",", ";", ":"]
        
        // PRIORITY 3: Natural pauses (dash, parentheses)
        let naturalPauses: Set<Character> = ["-", "—", "(", ")", "[", "]"]
        
        // PRIORITY 4: Conjunctions and connecting words (look for " and ", " or ", " but ", etc.)
        let conjunctions = [" and ", " or ", " but ", " so ", " yet ", " for ", " nor ", " because ", " since ", " while ", " although ", " however ", " therefore ", " moreover "]
        
        // Priority 1: Look for strong sentence breaks near ideal position
        for i in (minCharLen...safeIdealPosition).reversed() {
            let char = characters[i]
            if char == "." {
                let isPreviousDigit = i > 0 && characters[i - 1].isNumber
                let isNextDigit = i + 1 < characters.count && characters[i + 1].isNumber
                if !(isPreviousDigit && isNextDigit) {
                    // Ensure we don't break on abbreviations like "Mr." or "etc."
                    if i + 2 < characters.count && characters[i + 1] == " " && characters[i + 2].isUppercase {
                        return i + 1 // Include the space after period
                    } else if i + 1 < characters.count && characters[i + 1] == " " {
                        return i + 1
                    }
                    return i
                }
            } else if strongBreaks.contains(char) {
                return i + 1 < characters.count && characters[i + 1] == " " ? i + 1 : i
            }
        }
        
        // Priority 2: Look for clause breaks
        for i in (minCharLen...safeIdealPosition).reversed() {
            let char = characters[i]
            if clauseBreaks.contains(char) {
                return i + 1 < characters.count && characters[i + 1] == " " ? i + 1 : i
            }
        }
        
        // Priority 3: Look for natural pauses
        for i in (minCharLen...safeIdealPosition).reversed() {
            let char = characters[i]
            if naturalPauses.contains(char) {
                return i
            }
        }
        
        // Priority 4: Look for conjunctions
        for conjunction in conjunctions {
            if let range = text.range(of: conjunction, options: [.backwards, .caseInsensitive]) {
                let index = text.distance(from: text.startIndex, to: range.lowerBound)
                if index >= minCharLen && index <= safeIdealPosition {
                    return index
                }
            }
        }
        
        // Priority 5: Look for word boundaries (spaces) near ideal position
        for i in (minCharLen...safeIdealPosition).reversed() {
            if characters[i] == " " && i > 0 && !characters[i - 1].isWhitespace {
                return i
            }
        }
        
        // Priority 6: NEVER break in the middle of words - find ANY space, even below minCharLen
        // First try within the normal range
        for i in (minCharLen...limit - 1).reversed() {
            if characters[i] == " " {
                return i
            }
        }
        
        // If no space found in normal range, search backwards from minCharLen to find ANY space
        // This ensures we never cut in the middle of a word, even if it means a shorter chunk
        for i in (0..<minCharLen).reversed() {
            if characters[i] == " " {
                print("[Chunking] WARNING: Had to go below minCharLen to find space at index \(i)")
                return i
            }
        }
        
        // Absolute last resort: if somehow no spaces exist at all (very rare edge case)
        // Find the last character that's not alphanumeric to avoid breaking words
        for i in (0...limit - 1).reversed() {
            let char = characters[i]
            if !char.isLetter && !char.isNumber {
                print("[Chunking] WARNING: No spaces found, breaking at non-alphanumeric char at index \(i)")
                return i
            }
        }
        
        // Ultimate fallback - should almost never happen
        print("[Chunking] CRITICAL: No safe break points found, using limit - 1")
        return limit - 1
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
