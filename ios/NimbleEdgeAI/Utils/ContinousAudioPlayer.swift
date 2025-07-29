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
    
    func queueAudio(queueNumber: Int, pcm: [Float]) {
        print("🔊 [Queue] Enqueued chunk \(queueNumber), total queued: \(audioQueue.count)")
        lock.lock()
        defer { lock.unlock() }
        if audioQueue[queueNumber] == nil {
            audioQueue[queueNumber] = pcm
        }
    }
    
    func queueAudio(queueNumber: Int, pcm: [Int32]) {
        print("🔊 [Queue] filler queue Enqueued chunk \(queueNumber), total queued: \(audioQueue.count)")

        lock.lock()
        defer { lock.unlock() }
        if audioQueue[queueNumber] == nil {
            audioQueue[queueNumber] = pcm
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
    
    private func continuousPlaybackLoop() async {
        
        //TODO: NEED A WAY TO STOP THIS
        while true {
            let nextSegment = audioQueue[expectedQueue.getValue()]
            print("expectedQueue: \(expectedQueue)")
            
            if let nextSegment = nextSegment {
                
                lock.withLock({
                    _ = audioQueue.removeValue(forKey: expectedQueue.getValue())
                    expectedQueue.increment()
                })

                //isPlayingOrMightPlaySoonSubject.send(true)
                
                if let intNextSegment = nextSegment as? [Int32] {
                    await playAudioSegment(pcmData: intNextSegment)
                } else if let flotNextSegment = nextSegment as? [Float] {
                    await playAudioSegment(pcmData: flotNextSegment)
                }
                
            }else {
                try? await Task.sleep(nanoseconds: 100_000_000) // 100 ms
            }
        }
    }
    
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    
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
//    
    private func littleEndianBytes<T: FixedWidthInteger>(of value: T) -> Data {
        var mutableValue = value.littleEndian
        return Data(bytes: &mutableValue, count: MemoryLayout<T>.size)
    }
//    
//    
//
//    //TODO: Direclty play the audio insted of creating a wav file
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

            let header = createWavHeader(dataSize: pcmBuffer.count, sampleRate: 24000)
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
        playbackLoopTask?.cancel()
        currentAudioPlayer?.stop()
    }
    

}


extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
