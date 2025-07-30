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
    private let lock = NSLock()
    private var audioQueue = [Int: [Any]]() 
    private var expectedQueue = AtomicInteger(value: 1)
    private var currentAudioPlayer: AVAudioPlayer?
    private var playbackLoopTask: Task<Void, Never>?
    private var audioEngine: AVAudioEngine?
    private var audioPlayerNode: AVAudioPlayerNode?
    
    init(sampleRate: Int = 24000) {
        self.sampleRate = sampleRate
        startContinuousPlaybackLoop()
    }
    
    func isPlayingOrMightPlaySoonSubject() -> Bool {
        let trackPlaying = currentAudioPlayer != nil && currentAudioPlayer!.isPlaying
        return (!audioQueue.isEmpty || trackPlaying)
    }
    
    func queueAudio(queueNumber: Int, pcm: [Any]) {
        lock.withLock {
            if audioQueue[queueNumber] == nil {
                audioQueue[queueNumber] = pcm
                print("🔊 [Queue] Enqueued chunk \(queueNumber), total queued: \(audioQueue.count)")
                print("🔊 [Queue] Current queue keys: \(Array(audioQueue.keys).sorted())")
                print("🔊 [Queue] Expected next: \(expectedQueue.getValue())")
            }
        }
    }
    
    func cancelPlaybackAndResetQueue() {
        // Stop the current audio if playing
        if let player = currentAudioPlayer {
            player.stop()
            currentAudioPlayer = nil
        }
        
        // Stop audio engine if playing
        audioPlayerNode?.stop()
        audioEngine?.stop()
        audioPlayerNode = nil
        audioEngine = nil
        
        // Cancel playback loop
        playbackLoopTask?.cancel()
        
        // Thread-safe queue reset
        lock.withLock {
            audioQueue.removeAll()
        }
        expectedQueue.set(1)
        
        // Restart the playback loop
        startContinuousPlaybackLoop()
    }
    
    private func startContinuousPlaybackLoop() {
        playbackLoopTask = Task(priority: .userInitiated) {
            await continuousPlaybackLoop()
        }
    }
    
    private func continuousPlaybackLoop() async {
        print("🔊 Playback loop started")
        while !Task.isCancelled {
            let queueNumber = expectedQueue.getValue()
            var segment: [Any]?
            
            print("🔊 [Loop] Looking for chunk \(queueNumber), queue has: \(Array(audioQueue.keys).sorted())")

            // Fetch next segment thread-safely
            lock.withLock {
                segment = audioQueue[queueNumber]
                if segment != nil {
                    print("🔊 [Loop] Found chunk \(queueNumber), removing from queue")
                    audioQueue.removeValue(forKey: queueNumber)
                } else {
                    print("🔊 [Loop] Chunk \(queueNumber) not found in queue")
                }
            }

            if let nextSegment = segment {
                print("🔊 About to play queue number: \(queueNumber) @ \(Date().timeIntervalSince1970)")
                print("🔊 [Loop] Chunk \(queueNumber) type: \(type(of: nextSegment)), count: \(nextSegment.count)")
                if let intSeg = nextSegment as? [Int32] {
                    print("🔊 [Loop] Playing Int32 segment with \(intSeg.count) samples")
                    await playAudioSegment(pcmData: intSeg)
                } else if let floatSeg = nextSegment as? [Float] {
                    print("🔊 [Loop] Playing Float segment with \(floatSeg.count) samples")
                    await playAudioSegment(pcmData: floatSeg)
                } else {
                    print("🔊 [Loop] ERROR: Unknown segment type: \(type(of: nextSegment))")
                }
                print("🔊 [Loop] Finished playing chunk \(queueNumber), incrementing to \(queueNumber + 1)")
                expectedQueue.increment()
            } else {
                // No chunk ready, wait and retry
                try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
            }
        }
        print("🔊 Playback loop ended")
    }
    
    private func playAudioSegment(pcmData: [Float], sampleRate: Double = 24000) async {
        print("🔊 [Audio] Starting Float playback: \(pcmData.count) samples")
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        )!

        let frameCount = AVAudioFrameCount(pcmData.count)
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("Failed to allocate audio buffer")
            return
        }

        audioBuffer.frameLength = frameCount
        let floatChannelData = audioBuffer.floatChannelData![0]

        for i in 0..<pcmData.count {
            floatChannelData[i] = max(-1.0, min(1.0, pcmData[i])) // Clamp between -1 and 1
        }

        let engine = AVAudioEngine()
        let playerNode = AVAudioPlayerNode()
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)

        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)

        do {
            print("🔊 [Audio] Starting engine and scheduling buffer")
            try engine.start()
            playerNode.play()
            playerNode.scheduleBuffer(audioBuffer, at: nil, options: []) {
                print("🔊 [Audio] Buffer finished playing")
                Task { @MainActor in
                    playerNode.stop()
                    engine.stop()
                    self.audioPlayerNode = nil
                    self.audioEngine = nil
                }
            }

            // Retain strong references so the engine isn't deallocated mid-playback
            self.audioEngine = engine
            self.audioPlayerNode = playerNode

            print("🔊 [Audio] Waiting for playback to complete...")
            // Wait for playback to complete
            var waitCount = 0
            let maxWaitCount = 200 // 10 seconds max wait
            while playerNode.isPlaying && !Task.isCancelled && waitCount < maxWaitCount {
                waitCount += 1
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
            
            if waitCount >= maxWaitCount {
                print("🔊 [Audio] WARNING: Playback wait timeout, forcing completion")
            }
            
            print("🔊 [Audio] Float playback completed")

        } catch {
            print("Error playing audio segment: \(error)")
        }
    }
    
    deinit {
        playbackLoopTask?.cancel()
        currentAudioPlayer?.stop()
    }
}

//TODO: Create a function that works without creating .wav file for [Int32]
extension ContinuousAudioPlayer {
    
    private func playAudioSegment(pcmData: [Int32]) async {
        print("🔊 [Audio] Starting Int32 playback: \(pcmData.count) samples")
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

            print("🔊 [Audio] Created WAV file: \(tempFile.lastPathComponent), size: \(fileSize ?? 0) bytes")
            let player = try AVAudioPlayer(contentsOf: tempFile)

            currentAudioPlayer = player
            player.prepareToPlay()
            print("🔊 [Audio] Starting Int32 playback...")
            player.play()

            // Wait for playback to complete
            while player.isPlaying && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }

            print("🔊 [Audio] Int32 playback completed")
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
    
}


extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
