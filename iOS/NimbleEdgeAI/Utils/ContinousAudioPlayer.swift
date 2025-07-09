/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import AVFoundation
import Combine

class ContinuousAudioPlayer {
    private let sampleRate: Int
    private let queue = DispatchQueue(label: "com.nimbleedge.audioPlayer", qos: .userInitiated)
    private let lock = NSLock()
    private var audioQueue = [Int: [Float]]()
    private var fillerAudioQueue = [Int: [Int32]]()
    private var expectedQueue = 1
    var expectedFillerQueue = 1
    private var currentAudioPlayer: AVAudioPlayer?
    static let shared = ContinuousAudioPlayer()
    
    private let isPlayingOrMightPlaySoonSubject = CurrentValueSubject<Bool, Never>(false)
    var isPlayingOrMightPlaySoonPublisher: AnyPublisher<Bool, Never> {
        isPlayingOrMightPlaySoonSubject.eraseToAnyPublisher()
    }
    
    private var playerMonitorTask: Task<Void, Never>?
    private var playbackLoopTask: Task<Void, Never>?
    
    private init(sampleRate: Int = 22050) {
        self.sampleRate = sampleRate
        
        playbackLoopTask = Task(priority: .userInitiated) {
            await continuousPlaybackLoop()
        }
        
        playerMonitorTask = Task(priority: .userInitiated) {
            while !Task.isCancelled {
                let queueNotEmpty: Bool
                lock.lock()
                queueNotEmpty = !audioQueue.isEmpty
                lock.unlock()
                
                let trackPlaying = currentAudioPlayer != nil && (currentAudioPlayer?.isPlaying ?? false)
                isPlayingOrMightPlaySoonSubject.send(queueNotEmpty || trackPlaying)
                
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
    }
    
    func queueAudio(queueNumber: Int, pcm: [Float]) {
        print("🔊 [Queue] Enqueued chunk \(queueNumber), total queued: \(audioQueue.count)")
        lock.lock()
        defer { lock.unlock() }
        if audioQueue[queueNumber] == nil {
            audioQueue[queueNumber] = pcm
        }
    }
    func queueAudio(queueNumber: Int, pcm: [Int32]) {
        print("🔊 [Queue] filler queue Enqueued chunk \(queueNumber), total queued: \(fillerAudioQueue.count)")

        lock.lock()
        defer { lock.unlock() }
        if fillerAudioQueue[queueNumber] == nil {
            fillerAudioQueue[queueNumber] = pcm
        }
    }
    private func continuousPlaybackLoop() async {
        while !Task.isCancelled {
            lock.lock()
            let nextSegment = audioQueue[expectedQueue]
            lock.unlock()
            
            if let nextSegment = nextSegment {
                lock.lock()
                _ = audioQueue.removeValue(forKey: expectedQueue)
                expectedQueue += 1
                lock.unlock()

                isPlayingOrMightPlaySoonSubject.send(true)
                await playAudioSegment(pcmData: nextSegment)
            }else {
                lock.lock()
                let nextFillerSegment = fillerAudioQueue[expectedFillerQueue]
                let hasMainAudio = audioQueue[expectedQueue] != nil
                lock.unlock()
                
                if hasMainAudio {
                    lock.lock()
                    fillerAudioQueue.removeAll()
                    expectedFillerQueue = 0
                    lock.unlock()
                } else if let fillerSegment = nextFillerSegment {
                    isPlayingOrMightPlaySoonSubject.send(true)
                    await playAudioSegment(pcmData: fillerSegment)

                    lock.lock()
                    expectedFillerQueue += 1
                    lock.unlock()
                } else {
                    try? await Task.sleep(nanoseconds: 100_000_000) // 100 ms
                }
            }
        }
    }

    
    private func playAudioSegment(pcmData: [Int32]) async {
        var pcmBuffer = Data()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        for value in pcmData {
            let clampedValue = Int16((value % Int32(Int16.max)))  // Ensure correct type casting
            withUnsafeBytes(of: clampedValue.littleEndian) { pcmBuffer.append(contentsOf: $0) }
        }
        do {

            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".wav")

            let header = createWAVHeader(dataSize: UInt32(pcmBuffer.count), sampleRate: UInt32(sampleRate))


            try (header + pcmBuffer).write(to: tempFile)
            let fileSize = try FileManager.default.attributesOfItem(atPath: tempFile.path)[.size] as? Int

            let player = try AVAudioPlayer(contentsOf: tempFile)

            currentAudioPlayer = player
            player.prepareToPlay()
            player.play()

            // Wait for playback to complete
            while player.isPlaying && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            currentAudioPlayer = nil

            try? FileManager.default.removeItem(at: tempFile)

        } catch {
            print("Error playing audio segment: \(error)")
            currentAudioPlayer = nil
        }
    }
    
    private func createWAVHeader(dataSize: UInt32, sampleRate: UInt32) -> Data {
        var header = Data()
        
        // RIFF chunk descriptor
        header.append("RIFF".data(using: .ascii)!)
        let chunkSize: UInt32 = 36 + dataSize
        withUnsafeBytes(of: chunkSize.littleEndian) { header.append(contentsOf: $0) }
        header.append("WAVE".data(using: .ascii)!)
        
        // "fmt " sub-chunk
        header.append("fmt ".data(using: .ascii)!)
        let subchunk1Size: UInt32 = 16
        withUnsafeBytes(of: subchunk1Size.littleEndian) { header.append(contentsOf: $0) }
        let audioFormat: UInt16 = 1 // PCM
        withUnsafeBytes(of: audioFormat.littleEndian) { header.append(contentsOf: $0) }
        let numChannels: UInt16 = 1 // Mono
        withUnsafeBytes(of: numChannels.littleEndian) { header.append(contentsOf: $0) }
        withUnsafeBytes(of: sampleRate.littleEndian) { header.append(contentsOf: $0) }
        let byteRate: UInt32 = sampleRate * UInt32(numChannels) * 2
        withUnsafeBytes(of: byteRate.littleEndian) { header.append(contentsOf: $0) }
        let blockAlign: UInt16 = numChannels * 2
        withUnsafeBytes(of: blockAlign.littleEndian) { header.append(contentsOf: $0) }
        let bitsPerSample: UInt16 = 16
        withUnsafeBytes(of: bitsPerSample.littleEndian) { header.append(contentsOf: $0) }
        
        // "data" sub-chunk
        header.append("data".data(using: .ascii)!)
        withUnsafeBytes(of: dataSize.littleEndian) { header.append(contentsOf: $0) }
        
        return header
    }
    private func createWavHeader(dataSize: Int, sampleRate: Int) -> Data {
        let headerSize = 44
        let totalSize = dataSize + headerSize - 8
        
        var header = Data()
        
        header.append("RIFF".data(using: .ascii)!)                  // ChunkID
        header.append(littleEndianBytes(of: UInt32(totalSize)))     // ChunkSize
        header.append("WAVE".data(using: .ascii)!)                  // Format
        header.append("fmt ".data(using: .ascii)!)                  // Subchunk1ID
        header.append(littleEndianBytes(of: UInt32(16)))            // Subchunk1Size
        header.append(littleEndianBytes(of: UInt16(1)))             // AudioFormat (PCM)
        header.append(littleEndianBytes(of: UInt16(1)))             // NumChannels (Mono)
        header.append(littleEndianBytes(of: UInt32(sampleRate)))    // SampleRate
        header.append(littleEndianBytes(of: UInt32(sampleRate * 2))) // ByteRate
        header.append(littleEndianBytes(of: UInt16(2)))             // BlockAlign
        header.append(littleEndianBytes(of: UInt16(16)))            // BitsPerSample
        header.append("data".data(using: .ascii)!)                  // Subchunk2ID
        header.append(littleEndianBytes(of: UInt32(dataSize)))      // Subchunk2Size
        
        return header
    }
    
    private func littleEndianBytes<T: FixedWidthInteger>(of value: T) -> Data {
        var mutableValue = value.littleEndian
        return Data(bytes: &mutableValue, count: MemoryLayout<T>.size)
    }
    
    
    func reset() {
        Task(priority: .userInitiated) {
            // Stop current playback
            if let player = currentAudioPlayer {
                player.stop()
                currentAudioPlayer = nil
            }
            
            // Clear queue
            lock.lock()
            audioQueue.removeAll()
            expectedQueue = 1
            lock.unlock()
            
            isPlayingOrMightPlaySoonSubject.send(false)
        }
    }
    
    private func playAudioSegment(pcmData: [Float]) async {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        var pcmBuffer = Data()
        for sample in pcmData {
            let clamped = max(-1.0, min(1.0, sample))
            let int16Sample = Int16(clamped * Float(Int16.max))
            withUnsafeBytes(of: int16Sample.littleEndian) { pcmBuffer.append(contentsOf: $0) }
        }

        do {
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(UUID().uuidString + ".wav")

            let header = createWavHeader(dataSize: pcmBuffer.count, sampleRate: 22050)
            try (header + pcmBuffer).write(to: tempFile)

            let player = try AVAudioPlayer(contentsOf: tempFile)
            currentAudioPlayer = player
            player.prepareToPlay()
            player.play()

            while player.isPlaying && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            currentAudioPlayer = nil
            try? FileManager.default.removeItem(at: tempFile)
            
        } catch {
            print("Error playing audio segment: \(error)")
            currentAudioPlayer = nil
        }
    }
    
    deinit {
        playerMonitorTask?.cancel()
        playbackLoopTask?.cancel()
        currentAudioPlayer?.stop()
    }
    
    func cancelPlaybackAndResetQueue() -> Int {
        Task(priority: .userInitiated) {
            // Stop the current audio if playing
            if let player = currentAudioPlayer {
                player.stop()
                currentAudioPlayer = nil
            }

            // Clear audio queue
            lock.lock()
            audioQueue.removeAll()
            expectedQueue = 1
            lock.unlock()

            isPlayingOrMightPlaySoonSubject.send(false)
        }
        return 1
    }
}
