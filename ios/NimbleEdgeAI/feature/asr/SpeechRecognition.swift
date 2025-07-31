/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI
import Speech
import SwiftUI
import AVFoundation

class SpeechRecognizer: NSObject, ObservableObject {
    @Published var transcript = ""
    @Published var isRecording = false
    @Published var isAuthorized = false
    @Published var errorMessage = ""
    var onRecordingStoped: (() -> Void)? = nil
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    override init() {
        super.init()

        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        guard let speechRecognizer = speechRecognizer else {
            errorMessage = "Speech recognizer not available"
            return
        }

        if !speechRecognizer.supportsOnDeviceRecognition {
            errorMessage = "On-device recognition not supported"
            return
        }

        speechRecognizer.delegate = self
        requestAuthorization()
    }

    private func requestAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.isAuthorized = true
                case .denied, .restricted, .notDetermined:
                    self?.isAuthorized = false
                    self?.errorMessage = "Speech recognition not authorized"
                @unknown default:
                    self?.isAuthorized = false
                    self?.errorMessage = "Unknown authorization status"
                }
            }
        }
    }

    func startRecording() {
        guard isAuthorized else {
            errorMessage = "Not authorized for speech recognition"
            return
        }

        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session setup failed: \(error.localizedDescription)"
            return
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request"
            return
        }

        recognitionRequest.requiresOnDeviceRecognition = true

        let inputNode = audioEngine.inputNode

        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            var isFinal = false

            if let result = result {
                DispatchQueue.main.async {
                    self?.transcript = result.bestTranscription.formattedString
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                DispatchQueue.main.async {
                    self?.audioEngine.stop()
                    inputNode.removeTap(onBus: 0)
                    self?.recognitionRequest = nil
                    self?.recognitionTask = nil
                    self?.isRecording = false

                    // Reset audio session back to playback mode for TTS
                    do {
                        try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                        try AVAudioSession.sharedInstance().setActive(true)
                    } catch {
                        print("Failed to reset audio session to playback: \(error)")
                    }

                    if let error = error {
                        self?.errorMessage = "Recognition error: \(error.localizedDescription)"
                    }
                }
            }
        }


        let recordingFormat = inputNode.outputFormat(forBus: 0)
        var lastSpokenTime = Date()

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
            
            // Volume analysis
            let channelData = buffer.floatChannelData?[0]
            let channelDataValueArray = stride(from: 0,
                                               to: Int(buffer.frameLength),
                                               by: buffer.stride).map { channelData?[$0] ?? 0 }

            let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
            let avgPower = 20 * log10(rms)

            if avgPower > -45 {
                lastSpokenTime = Date()
            } else {
                if Date().timeIntervalSince(lastSpokenTime) > 2.0 {
                    DispatchQueue.main.async {
                        self.stopRecording()
                        self.onRecordingStoped?()
                    }
                }
            }

        }

        audioEngine.prepare()

        do {
            try audioEngine.start()
            isRecording = true
            transcript = ""
            errorMessage = ""
        } catch {
            errorMessage = "Audio engine start failed: \(error.localizedDescription)"
        }
    }

    func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isRecording = false
        
        // Reset audio session back to playback mode for TTS
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to reset audio session to playback: \(error)")
        }
    }
}

extension SpeechRecognizer: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async { [weak self] in
            if !available {
                self?.errorMessage = "Speech recognizer became unavailable"
                self?.stopRecording()
            }
        }
    }
}
