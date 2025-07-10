/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */
 
import SwiftUI
import Combine

struct DownloadingView: View {
    
    @StateObject var progressManager: DownloadProgressManager
    let onDownloadCompleted: (() -> Void)
    @State private var progress: CGFloat = 0
    @State private var lastProgress: CGFloat = 0
    @State private var inReset: Bool = false
    @State private var blinkAlpha: CGFloat = 1.0
    
    private let progressPublisher = PassthroughSubject<CGFloat, Never>()
    
    var body: some View {
        ZStack {
                Color.backgroundPrimary
                    .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 16) {
                
                VStack(spacing: 3) {
                    Text("Please wait")
                        .font(.body.weight(.medium))
                        .foregroundColor(.textPrimary)
                    
                    Text("I'm taking care of a few things…")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                }
                
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.backgroundSecondary)
                        .frame(height: 20)
                        .opacity(blinkAlpha)
                    
                    GeometryReader { geometry in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentHigh1)
                            .frame(width: geometry.size.width * progress)
                            .frame(height: 20)
                    }
                    .opacity(blinkAlpha)
                    
                    Text("\(Int(progressManager.percentageCompleted))%")
                        .font(.caption.weight(.bold))
                        .foregroundColor(Color.textPrimary.opacity(0.8))
                        .opacity(blinkAlpha)
                }
                .frame(height: 20)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                
            
                Text(progressManager.currentMessage + " " + progressManager.downloadedSizeText)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .opacity(blinkAlpha)
            }
            .padding(24)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                blinkAlpha = 0.8
            }
            
            updateProgress(to: restrictPercentageDomain(progressManager.percentageCompleted))
        }
        .onChange(of: progressManager.percentageCompleted) { newValue in
            let currentProgress = restrictPercentageDomain(newValue)
            
            if currentProgress >= 1.0 || abs(currentProgress - lastProgress) > 0.02 {
                // Jump directly to the new value
                progress = currentProgress
                lastProgress = currentProgress
            } else {
                progressPublisher.send(currentProgress)
            }
        }
        .onChange(of: progressManager.llmDowonloadIsReady) { newValue in
            if newValue {
                onDownloadCompleted()
            }
        }
        .onReceive(progressPublisher) { targetProgress in
            handleProgressUpdate(targetProgress: targetProgress)
        }
    }
    
    private func restrictPercentageDomain(_ value: Float) -> CGFloat {
        return CGFloat(value / 100.0).clamped(to: 0.0...1.0)
    }
    
    private func updateProgress(to newValue: CGFloat) {
        progress = newValue
        lastProgress = newValue
    }
    
    private func handleProgressUpdate(targetProgress: CGFloat) {
        if !inReset && targetProgress < lastProgress {
            inReset = true
            
            // Animate to full, then reset to zero and animate to target
            withAnimation(.easeInOut(duration: 0.2)) {
                progress = 1.0
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                progress = 0.0
                
                withAnimation(.easeInOut(duration: 0.1)) {
                    progress = targetProgress
                }
                
                lastProgress = targetProgress
                inReset = false
            }
        } else if !inReset {
            // Normal progress update
            withAnimation(.easeInOut(duration: 0.5)) {
                progress = targetProgress
                lastProgress = targetProgress
            }
        }
    }
}
