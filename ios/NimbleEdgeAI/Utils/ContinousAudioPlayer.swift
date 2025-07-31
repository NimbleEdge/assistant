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
    var audioQueue = [Int: [Any]]() 
    private var expectedQueueNumber = AtomicInteger(value: 1)
    var onFinshedPlaying: ((_ queue: Int) -> Void)?
    private var playbackLoopTask: Task<Void, Never>?
    private var audioEngine: AVAudioEngine
    private var audioPlayerNode: AVAudioPlayerNode
    private var audioFormat: AVAudioFormat
    private var isEngineRunning = false
    
    init(sampleRate: Int = 24000) {
        self.sampleRate = sampleRate
        
        self.audioFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Double(sampleRate),
            channels: 1,
            interleaved: true
        )!
        
        self.audioEngine = AVAudioEngine()
        self.audioPlayerNode = AVAudioPlayerNode()
        
        setupAudioEngine()
    }
    
    private func setupAudioEngine() {
        audioEngine.attach(audioPlayerNode)
        audioEngine.connect(audioPlayerNode, to: audioEngine.mainMixerNode, format: audioFormat)
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            try audioEngine.start()
            isEngineRunning = true
            print("[Engine] Persistent audio engine started successfully")
        } catch {
            print("[Engine] Failed to start audio engine: \(error)")
            isEngineRunning = false
        }
    }
    
    func isPlayingOrHasQueuedAudio() -> Bool {
        let trackPlaying = audioPlayerNode.isPlaying
        return (!audioQueue.isEmpty || trackPlaying)
    }
    
    func enqueueAudio(queueNumber: Int, pcm: [Any]) {
        lock.withLock {
            if audioQueue[queueNumber] == nil {
                audioQueue[queueNumber] = pcm
                print("[Queue] Enqueued chunk \(queueNumber), total queued: \(audioQueue.count)")
                print("[Queue] Current queue keys: \(Array(audioQueue.keys).sorted())")
                print("[Queue] Expected next: \(expectedQueueNumber.getValue())")
            } else {
                print("[Queue] WARNING: Attempted to queue duplicate chunk \(queueNumber) - ignoring")
                print("[Queue] Current queue keys: \(Array(audioQueue.keys).sorted())")
            }
        }
    }
    
    func skipCurrentQueue(){
        expectedQueueNumber.increment()
    }
    
    func hasQueuedAudio(queueNumber: Int) -> Bool {
        return lock.withLock {
            audioQueue[queueNumber] != nil
        }
    }
    
    func getExpectedQueueNumber() -> Int {
        return expectedQueueNumber.getValue()
    }
    
    func jumpToQueue(_ queueNumber: Int) {
        expectedQueueNumber.set(queueNumber)
        print("[Skip] Jumped to queue #\(queueNumber)")
    }
    
    func stopAndResetPlayback() {
        audioPlayerNode.stop()
        audioPlayerNode.reset()
        
        playbackLoopTask?.cancel()
        
        lock.withLock {
            audioQueue.removeAll()
        }
        expectedQueueNumber.set(1)
        
        // Always restart audio engine to ensure clean state after potential ASR session
        audioEngine.stop()
        isEngineRunning = false
        setupAudioEngine()
    }
    
    func startPlaybackLoop() {
        playbackLoopTask = Task(priority: .userInitiated) {
            await continuousPlaybackLoop()
        }
    }
    
    private func continuousPlaybackLoop() async {
        print("Playback loop started")
        while !Task.isCancelled {
            let queueNumber = expectedQueueNumber.getValue()
            var segment: [Any]?
            
            // Clean up old chunks that are behind our expected position
            lock.withLock {
                let oldChunks = audioQueue.keys.filter { $0 < queueNumber }
                for oldChunk in oldChunks {
                    audioQueue.removeValue(forKey: oldChunk)
                    print("[Cleanup] Removed old chunk \(oldChunk)")
                }
            }
            
            // Check if we should skip queue 2 (second filler) and jump to queue 3 (first LLM audio)
            if queueNumber == 2 && hasQueuedAudio(queueNumber: 3) && !hasQueuedAudio(queueNumber: 2) {
                print("[Skip] Queue 2 not found but queue 3 available - skipping second filler and jumping to queue 3")
                jumpToQueue(3)
                continue // Restart loop with new queue number
            }
            
            print("[Loop] Looking for chunk \(queueNumber), queue has: \(Array(audioQueue.keys).sorted())")

            lock.withLock {
                segment = audioQueue[queueNumber]
                if segment != nil {
                    print("[Loop] Found chunk \(queueNumber), removing from queue")
                    audioQueue.removeValue(forKey: queueNumber)
                } else {
                    print("[Loop] Chunk \(queueNumber) not found in queue")
                }
            }

            if let nextSegment = segment {
                print("About to play queue number: \(queueNumber) @ \(Date().timeIntervalSince1970)")
                print("[Loop] Chunk \(queueNumber) type: \(type(of: nextSegment)), count: \(nextSegment.count)")
                if let intSeg = nextSegment as? [Int32] {
                    print("[Loop] Playing Int32 segment with \(intSeg.count) samples")
                    await playAudioSegment(pcmData: intSeg)
                } else if let floatSeg = nextSegment as? [Float] {
                    print("[Loop] Playing Float segment with \(floatSeg.count) samples")
                    await playAudioSegment(pcmData: floatSeg)
                } else {
                    print("[Loop] ERROR: Unknown segment type: \(type(of: nextSegment))")
                }
                print("[Loop] Finished playing chunk \(queueNumber), incrementing to \(queueNumber + 1)")
                onFinshedPlaying?(queueNumber)
                expectedQueueNumber.increment()
            } else {
                try? await Task.sleep(nanoseconds: 50_000_000) // 50 ms
            }
        }
        print("Playback loop ended")
    }
    
    private func playAudioSegment(pcmData: [Float], sampleRate: Double = 24000) async {
        print("[Audio] Scheduling Float buffer: \(pcmData.count) samples")
         
        if !isEngineRunning {
            print("[Audio] Engine not running, attempting restart")
            setupAudioEngine()
            guard isEngineRunning else {
                print("[Audio] Failed to restart engine, skipping chunk")
                return
            }
        }
        
        let frameCount = AVAudioFrameCount(pcmData.count)
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            print("[Audio] Failed to allocate audio buffer")
            return
        }
        
        audioBuffer.frameLength = frameCount
        let floatChannelData = audioBuffer.floatChannelData![0]
        
        for i in 0..<pcmData.count {
            floatChannelData[i] = max(-1.0, min(1.0, pcmData[i]))
        }
        
        if !audioPlayerNode.isPlaying {
            audioPlayerNode.play()
            print("[Audio] Started audio player node")
        }
        
        audioPlayerNode.scheduleBuffer(audioBuffer, at: nil, options: []) {
            print("[Audio] Buffer completed: \(pcmData.count) samples")
        }
        
        print("[Audio] Buffer scheduled successfully")
        
        // Calculate approximate playback duration for pacing
        let durationSeconds = Double(pcmData.count) / Double(sampleRate)
        let durationNanoseconds = UInt64(durationSeconds * 1_000_000_000)
        
        // Wait for most of the buffer duration to maintain proper pacing
        try? await Task.sleep(nanoseconds: durationNanoseconds)
    }
    
    deinit {
        playbackLoopTask?.cancel()
        audioPlayerNode.stop()
        audioEngine.stop()
    }
}

extension ContinuousAudioPlayer {
    
    private func playAudioSegment(pcmData: [Int32]) async {
        print("[Audio] Starting Int32 direct playback: \(pcmData.count) samples")
        
        if !isEngineRunning {
            print("[Audio] Engine not running, attempting restart")
            setupAudioEngine()
            guard isEngineRunning else {
                print("[Audio] Failed to restart engine, skipping chunk")
                return
            }
        }
        
        // Convert Int32 PCM data to Float format for direct playback
        let floatPCM = pcmData.map { value in
            let clampedValue = max(Int32(Int16.min), min(Int32(Int16.max), value))
            return Float(clampedValue) / Float(Int16.max)
        }
        
        print("[Audio] Converted \(pcmData.count) Int32 samples to Float format")
        
        let frameCount = AVAudioFrameCount(floatPCM.count)
        guard let audioBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: frameCount) else {
            print("[Audio] Failed to allocate audio buffer for Int32 data")
            return
        }
        
        audioBuffer.frameLength = frameCount
        let floatChannelData = audioBuffer.floatChannelData![0]
        
        for i in 0..<floatPCM.count {
            floatChannelData[i] = max(-1.0, min(1.0, floatPCM[i]))
        }
        
        if !audioPlayerNode.isPlaying {
            audioPlayerNode.play()
            print("[Audio] Started audio player node for Int32 data")
        }
        
        audioPlayerNode.scheduleBuffer(audioBuffer, at: nil, options: []) {
            print("[Audio] Int32 buffer completed: \(pcmData.count) samples")
        }
        
        print("[Audio] Int32 buffer scheduled successfully")
        
        let durationSeconds = Double(floatPCM.count) / Double(sampleRate)
        let durationNanoseconds = UInt64(durationSeconds * 1_000_000_000)
        
        try? await Task.sleep(nanoseconds: durationNanoseconds)
    }
    

    
}


extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
