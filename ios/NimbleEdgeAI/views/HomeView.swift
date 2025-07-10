/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import SwiftUI
import Lottie

enum HomeDestination: Hashable {
    case audioModeView
    case historyView
    case chatView
    case chatViewWith(chatID: String)
}

@available(iOS 16.0, *)
struct HomeView: View {
    @Binding var path: NavigationPath

    @ObservedObject var mainViewModel: MainViewModel
    @ObservedObject var historyViewModel: HistoryViewModel
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 0) {
                VStack(alignment: .center) {
                    HStack(alignment: .center) {
                        Image("ic_ne_logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 24)
                        
                        Spacer()
                            .frame(width: 8)
                        
                        HStack(spacing: 0) {
                            Text("NimbleEdge ")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.textPrimary)
                            
                            Text("AI")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.accent)
                        }
                    }
                    
                    Spacer()
                        .frame(height: 4)
                    
                    Text("How can I help you today?")
                        .font(.body)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
                
                Spacer()
                    .frame(height: 40)
                

                LottieView(animationName: "wave_teal", loopMode: .loop)

                
                Spacer()
                    .frame(height: 80)
                
                HStack(spacing: 16) {
                    ActionIcon(systemName: "clock", isPrimary: false, viewType: .history, action: {
                        path.append(HomeDestination.historyView)
                    }, mainViewModel: mainViewModel, historyViewModel: historyViewModel)
                    
                    ActionIcon(systemName: "message.circle.fill", isPrimary: true, viewType: .chat, action: {
                        path.append(HomeDestination.chatView)
                    }, mainViewModel: mainViewModel, historyViewModel: historyViewModel)
                    
                    ActionIcon(systemName: "waveform", isPrimary: false, viewType: .voice, action: {
                        path.append(HomeDestination.audioModeView)
                    }, mainViewModel: mainViewModel, historyViewModel: historyViewModel)
                }
                
                Spacer()
                    .frame(height: 32)
                
                Button {
                    openURL(URL(string: "https://www.nimbleedge.com/contact")!)
                } label: {
                    HStack(spacing: 0) {
                        Text("Have a suggestion? Feel free to")
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Text(" get in touch!")
                            .font(.caption)
                            .foregroundColor(.accent)
                    }
                }
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

struct ActionIcon: View {
    let systemName: String
    let isPrimary: Bool
    let viewType: ViewType
    let action: () -> Void
    @ObservedObject var mainViewModel: MainViewModel
    @ObservedObject var historyViewModel: HistoryViewModel
    
    enum ViewType {
        case history, chat, voice
    }
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack {
            if viewType == .chat && !mainViewModel.hasUserEverClickedOnChat() {
                CoachMarkOverChatIcon()
            } else {
                Text("Tap")
                    .font(.caption)
                    .foregroundColor(.clear)
            }
            
            Button(action: {
                action()
                mainViewModel.registerUserTapToChat()
            }) {
                Image(systemName: systemName)
                    .font(isPrimary ? .system(size: 20) : .system(size: 17))
                    .foregroundColor(isPrimary ? .textPrimary.opacity(isAnimating ? 0.7 : 1) : .textPrimary)
                    .frame(width: isPrimary ? 68 : 50, height: isPrimary ? 68 : 50)
                    .background(
                        Circle()
                            .fill(isPrimary ?
                                  (isAnimating ? Color.accentHigh1 : Color.accentLow2) :
                                    Color.accentLow2)
                    )
                    .scaleEffect(isPrimary && isAnimating ? 1.1 : 0.95)
            }
            .onAppear {
                if isPrimary {
                    withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                        isAnimating = true
                    }
                }
            }
        }
    }
}

struct CoachMarkOverChatIcon: View {
    @State private var yOffset: CGFloat = 0
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Tap to Chat")
                .font(.caption)
                .foregroundColor(.gray)
        }
        .offset(y: yOffset)
        .onAppear {
            withAnimation(Animation.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                yOffset = -12
            }
        }
    }
}

struct LottieView: UIViewRepresentable {
    
    let animationName: String
    let loopMode: LottieLoopMode
    
    init(animationName: String, loopMode: LottieLoopMode = .loop) {
        self.animationName = animationName
        self.loopMode = loopMode
    }
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView(frame: .zero)
        containerView.backgroundColor = .clear
        
        let animationView = LottieAnimationView(name: animationName)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = loopMode
        animationView.backgroundBehavior = .pauseAndRestore
        animationView.translatesAutoresizingMaskIntoConstraints = false
        
        containerView.addSubview(animationView)
        
        NSLayoutConstraint.activate([
            animationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            animationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            animationView.topAnchor.constraint(equalTo: containerView.topAnchor),
            animationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        
        animationView.play()
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}
