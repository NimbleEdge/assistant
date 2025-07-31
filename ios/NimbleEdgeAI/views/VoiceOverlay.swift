/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI
import AVFAudio
import Combine
enum VoiceOverlayState {
    case idle
    case speaking
}

struct VoiceOverlay: View {
    @ObservedObject var chatViewModel: ChatViewModel
    @StateObject private var speechRecognizer = SpeechRecognizer()
    @State var voiceState: VoiceOverlayState = .speaking
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 16) {
                AnimatedVoiceOrb(
                    voiceState: $voiceState,
                    normalizedVolume: normalizedVolume,
                    baseSize: 120,
                    chatViewModel: chatViewModel,
                    speechRecognizer: speechRecognizer
                )
                
                VStack {
                    
                    Text(
                        speechRecognizer.isRecording ? "Listening..." :
                        chatViewModel.isLLMSpeaking ? speechRecognizer.transcript :
                        "Tap to Speak! Ask me anything..."
                    )
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                
                if chatViewModel.isLLMSpeaking {
                    Text("Interrupt")
                        .foregroundColor(.white)
                        .onTapGesture {
                            chatViewModel.cancelTTS()
                        }
                }
            }
            VStack {
                HStack {
                    Spacer()
                    Button(action: {
                        speechRecognizer.stopRecording()
                        chatViewModel.isOverlayVisible = false
                        onDismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.white)
                            .font(.title2)
                    }
                    .padding()
                }
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: speechRecognizer.isRecording, perform: { newValue in
            voiceState = newValue ? .speaking : .idle
        })
        .onChange(of: chatViewModel.isLLMSpeaking, perform: { newValue in
            if chatViewModel.isLLMSpeaking == false {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: {
                    speechRecognizer.startRecording()
                })
            }
        })
        .onAppear {
            DispatchQueue.main.async(execute: {
                speechRecognizer.startRecording()
            })
            
            speechRecognizer.onRecordingStoped = {
                let finalTranscript = speechRecognizer.transcript
                chatViewModel.addNewMessageToChatHistory(message: finalTranscript, isUserInput: true)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: {
                    print("speechRecognizer.transcript ->> \(finalTranscript)")
                    chatViewModel.passTextInputToLLM(finalTranscript)
                })
            }
        }
        .onDisappear {
            if speechRecognizer.isRecording {
                speechRecognizer.stopRecording()
            }
        }
    }
    
    private var normalizedVolume: Float {
        return ((chatViewModel.volumeState + 120) / 120).clamped(to: 0...1)
    }
    
    private var currentState: VoiceOverlayState {
        return speechRecognizer.isRecording ? .speaking : .idle
    }
}

struct AnimatedVoiceOrb: View {
    @Binding var voiceState: VoiceOverlayState
    let normalizedVolume: Float
    let baseSize: CGFloat
    @ObservedObject var chatViewModel: ChatViewModel
    @ObservedObject var speechRecognizer: SpeechRecognizer
    
    @State private var idlePulse: CGFloat = 0.8
    @State private var rotation: Double = 0
    @State private var colorRotation: Double = 0
    @State private var waveAlpha: Double = 0.3
    
    var body: some View {
        ZStack {
            OuterWaveView(
                alpha: waveAlpha,
                colors: waveColors,
                size: baseSize
            )

            OrbShadowView(
                alpha: orbAlpha,
                startColor: startColor,
                endColor: endColor,
                size: baseSize
            )
            
            if loadingArcAlpha > 0 {
                RotatingLoadingArc(
                    alpha: loadingArcAlpha,
                    color: startColor,
                    rotation: rotation,
                    size: baseSize
                )
            }
            
            SphereSurfaceView(
                alpha: orbAlpha,
                startColor: startColor,
                midColor: midColor,
                endColor: endColor,
                rotation: colorRotation,
                size: baseSize,
                onTap: {
                    if speechRecognizer.isRecording {
                        speechRecognizer.stopRecording()
                        chatViewModel.addNewMessageToChatHistory(message: speechRecognizer.transcript, isUserInput: true)
                        chatViewModel.passTextInputToLLM(speechRecognizer.transcript)
                    } else {
                        speechRecognizer.startRecording()
                    }
                }
            )
        }
        .frame(width: baseSize, height: baseSize)
        .scaleEffect(currentScale)
        .onAppear {
            startAnimations()
        }
    }
    
    private var currentScale: CGFloat {
        switch voiceState {
        case .idle:
            return idlePulse
        case .speaking:
            return 1.0 + CGFloat(normalizedVolume) * 0.3
        }
    }
    
    private var orbAlpha: Double {
        switch voiceState {
        case .idle: return 0.8
        case .speaking: return 1.0
        }
    }
    
    private var loadingArcAlpha: Double {
        switch voiceState {
        case .idle: return 0.0
        case .speaking: return 0.0
        }
    }
    
    private var startColor: Color {
        switch voiceState {
        case .idle: return Color.accent
        case .speaking: return Color(hex: 0xFF972A2A)
        }
    }
    
    private var midColor: Color {
        switch voiceState {
        case .idle: return Color.accentHigh2
        case .speaking: return Color(hex: 0xFFD35B5B)
        }
    }
    
    private var endColor: Color {
        switch voiceState {
        case .idle: return Color.white
        case .speaking: return Color(hex: 0xFFEBC0C0)
        }
    }
    
    private var waveColors: [Color] {
        return [startColor, midColor, endColor]
    }
    
    private func startAnimations() {
        withAnimation(
            Animation.easeInOut(duration: 1.5)
                .repeatForever(autoreverses: true)
        ) {
            idlePulse = 0.95
        }
        
        withAnimation(
            Animation.linear(duration: 1.2)
                .repeatForever(autoreverses: false)
        ) {
            rotation = 360
        }
        
        withAnimation(
            Animation.linear(duration: 4.0)
                .repeatForever(autoreverses: false)
        ) {
            colorRotation = 360
        }
        
        withAnimation(
            Animation.linear(duration: 2.0)
                .repeatForever(autoreverses: true)
        ) {
            waveAlpha = 0.8
        }
    }
}

struct OrbShadowView: View {
    let alpha: Double
    let startColor: Color
    let endColor: Color
    let size: CGFloat
    
    var body: some View {
        if alpha > 0 {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            startColor.opacity(alpha * 0.3),
                            endColor.opacity(0)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.8
                    )
                )
                .frame(width: size * 1.6, height: size * 1.6)
        }
    }
}

struct RotatingLoadingArc: View {
    let alpha: Double
    let color: Color
    let rotation: Double
    let size: CGFloat
    
    var body: some View {
        if alpha > 0 {
            Circle()
                .trim(from: 0, to: 0.33)
                .stroke(
                    color.opacity(alpha),
                    style: StrokeStyle(
                        lineWidth: size / 10,
                        lineCap: .round
                    )
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(rotation))
        }
    }
}

struct SphereSurfaceView: View {
    let alpha: Double
    let startColor: Color
    let midColor: Color
    let endColor: Color
    let rotation: Double
    let size: CGFloat
    let onTap: () -> Void
    
    var body: some View {
        if alpha > 0 {
            Button(action: onTap) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                startColor.opacity(alpha),
                                midColor.opacity(alpha),
                                endColor.opacity(alpha)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: size, height: size)
            }
            .rotationEffect(.degrees(rotation))
            .buttonStyle(PlainButtonStyle())
        }
    }
}

struct OuterWaveView: View {
    let alpha: Double
    let colors: [Color]
    let size: CGFloat
    
    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        colors.first?.opacity(alpha * 0.2) ?? Color.clear,
                        colors.last?.opacity(alpha * 0.1) ?? Color.clear
                    ],
                    center: .center,
                    startRadius: 0,
                    endRadius: size / 1.3
                )
            )
            .frame(width: size * 1.3, height: size * 1.3)
    }
}
