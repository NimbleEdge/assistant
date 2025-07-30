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
        
        playbackLoopTask = Task(priority: .userInitiated) {
            await continuousPlaybackLoop()
        }
    }
    
    func isPlayingOrMightPlaySoonSubject() -> Bool {
        let trackPlaying = currentAudioPlayer != nil && currentAudioPlayer!.isPlaying
        return (!audioQueue.isEmpty || trackPlaying)
    }
    
    func queueAudio(queueNumber: Int, pcm: [Any]) {
        print("🔊 [Queue] Enqueued chunk \(queueNumber), total queued: \(audioQueue.count)")
        lock.lock()
        defer { lock.unlock() }
        if audioQueue[queueNumber] == nil {
            let startContinuousPlaybackLoop = isContinuousPlaybackLoopNotRunning()
            audioQueue[queueNumber] = pcm
            if startContinuousPlaybackLoop { self.startContinuousPlaybackLoop() }
        }
    }
    
    func cancelPlaybackAndResetQueue() {
        Task(priority: .userInitiated) {
            // Stop the current audio if playing
            if let player = currentAudioPlayer {
                player.stop()
                currentAudioPlayer = nil
            }

            // Clear audio queue
            audioQueue.removeAll()
            expectedQueue.set(1)
           // isPlayingOrMightPlaySoonSubject.send(false)
        }
    }
    
    private func startContinuousPlaybackLoop() {
        playbackLoopTask = Task(priority: .userInitiated) {
            await continuousPlaybackLoop()
        }
    }
    
    private func isContinuousPlaybackLoopNotRunning() -> Bool {
        (audioQueue.isEmpty && playbackLoopTask!.isCancelled)
    }
    
    private func continuousPlaybackLoop() async {
        
        while !audioQueue.isEmpty {
            let nextSegment = audioQueue[expectedQueue.getValue()]
            print("expectedQueue: \(expectedQueue.getValue())")
            
            if let nextSegment = nextSegment {
                
                let queueToBeRemoved = expectedQueue.getValue()
                Task {
                    _ = audioQueue.removeValue(forKey: queueToBeRemoved)
                }
            
                //isPlayingOrMightPlaySoonSubject.send(true)
                
                print("About to play queue number: \(queueToBeRemoved), time: \(Date().timeIntervalSince1970)")
                if let intNextSegment = nextSegment as? [Int32] {
                    await playAudioSegment(pcmData: intNextSegment)
                } else if let flotNextSegment = nextSegment as? [Float] {
                    await playAudioSegment(pcmData: flotNextSegment)
                }
                
                expectedQueue.increment()
                
            }else {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
            }
        }
        
        playbackLoopTask?.cancel()
    }
    
    private func playAudioSegment(pcmData: [Float], sampleRate: Double = 24000) async {
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
            try engine.start()
            playerNode.play()
            playerNode.scheduleBuffer(audioBuffer, at: nil, options: []) {
                Task { @MainActor in
                    playerNode.stop()
                    engine.stop()
                    self.audioPlayerNode = nil
                    self.audioEngine = nil
                }
            }

            audioEngine = engine
            audioPlayerNode = playerNode

            // Wait for playback to complete
            while playerNode.isPlaying && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 50_000_000)
            }

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
    
}


extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
