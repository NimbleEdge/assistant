/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */
 
import SwiftUI
import Combine
import AVFoundation
import DeliteAI
import Lottie

@available(iOS 16.0, *)
struct ChatView: View {
    @State private var tensorInfo: String? = nil
    @ObservedObject var chatViewModel: ChatViewModel
    @State private var userInput: String = ""
    @FocusState private var isTextFieldFocused: Bool
    @Binding var path: NavigationPath
    @State var hasScrolledToEnd: Bool = false
    @State private var showMicAccessAlert = false
    @State private var isOverlayVisible: Bool = false
    private var initialOverlayVisibility = false
    @State var keyboardHeight: CGFloat = 0
    private let allSuggestions = [
        "Design workout routine",
        "Recommend wine pairings",
        "Write a short poem",
        "Draft party menu",
        "Create smoothie blends",
        "Generate gift ideas",
        "Craft cocktail ideas",
        "Mix mocktail recipes",
        "Suggest hiking essentials",
        "Plan a game night",
        "Prep for camping",
        "Plan a movie marathon",
        "Invent signature cocktail",
        "Craft lunchbox ideas",
        "Who are you?",
        "Plan a solo trip",
        "Curate weekend playlist",
        "Plan a beach day"
    ]
    @State private var picks: [String] = []


    init(chatViewModel: ChatViewModel, path: Binding<NavigationPath>, chatID: String? = nil, isOverlayVisible:Bool = false) {
        self.chatViewModel = chatViewModel
        self._path = path
        self.initialOverlayVisibility = isOverlayVisible
        
        self.chatViewModel.reset()
        if let chatID = chatID {
            self.chatViewModel.set(chatID: chatID)
        }
    }

    var body: some View {
        VStack {
            NETopBar(onBackButtonPressed: {
                chatViewModel.reset()
                path.removeLast()
            }, onEditButtonPressed: {
                shuffleSuggestions()
                
                chatViewModel.reset()
            },onAudioModeButtonPressed: {
                openVoiceOverly()
            },title: "LLama 3.2", path: $path)
            
            if chatViewModel.chatHistory.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    
                    Text("How can I help you today?")
                        .font(.system(size: 20))
                        .fontWeight(.bold)
                        .foregroundColor(.textPrimary)
                        .multilineTextAlignment(.center)
                    
                    Text("You can use NimbleEdge AI while being completely offline. Give it a try!")
                        .font(.system(size: 16))
                        .foregroundColor(Color.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Spacer()
                    
                }
                .contentShape(Rectangle()) // Makes the entire area tappable
                .onTapGesture {
                    isTextFieldFocused = false
                }
                .padding(.horizontal, 30)
            } else {
                ChatTableView(chatViewModel: chatViewModel)
                    .onTapGesture(perform: {
                        isTextFieldFocused = false
                    })
            }
            
            if chatViewModel.chatHistory.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(picks, id: \.self) { item in
                            Text(item)
                                .font(.system(size: 15))
                                .background(.clear)
                                .foregroundColor(Color.textPrimary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20)
                                        .stroke(Color.accent, lineWidth: 1.5)
                                )
                                .padding(.vertical, 2)
                                .onTapGesture {
                                    chatViewModel.passTextInputToLLM(item)
                                    chatViewModel.addNewMessageToChatHistory(message: item, isUserInput: true)
                                }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            HStack {
                HStack(spacing: 15) {
                    CustomTextField(
                        text: $userInput,
                        placeholder: "Ask me anything",
                        isFocused: _isTextFieldFocused
                    )
                    
                    Button(action: {
                        if chatViewModel.isLLMActive {
                            chatViewModel.interruptResponse()
                        } else {
                            guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            isTextFieldFocused = false
                            chatViewModel.addNewMessageToChatHistory(message: userInput, isUserInput: true)
                            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
                                chatViewModel.passTextInputToLLM(userInput)
                                userInput = ""
                            }
                            
                        }
                    }
                    ) {
                        if chatViewModel.isLLMActive {
                            Image(systemName: "stop.fill")
                                .foregroundColor(Color.accent)
                                .frame(width: 24, height: 24)
                        } else {
                            Image("send-custom-icon")
                                .renderingMode(.template)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(Color.accent)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
                .padding(.horizontal)
                .background(Color.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
            }
                .padding(.bottom, 10)
                .padding(.horizontal, 24)
             }
        .overlay {
            if isOverlayVisible {
                VoiceOverlay(chatViewModel: chatViewModel) {
                    isOverlayVisible = false
                    chatViewModel.cancelTTS()
                    chatViewModel.setOverlayVisibility(false)
                    
                }
                .onAppear {
                    chatViewModel.setOverlayVisibility(true)
                }
            }
        }
        .alert(isPresented: $showMicAccessAlert) {
            Alert(
                title: Text("Microphone Access Needed"),
                message: Text("Please enable microphone access in Settings to use this feature."),
                primaryButton: .default(Text("Open Settings")) {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString),
                       UIApplication.shared.canOpenURL(settingsUrl) {
                        UIApplication.shared.open(settingsUrl)
                    }
                },
                secondaryButton: .cancel()
            )
        }
        .onAppear {
            //doing this because @state variable can not be changed from init and accepting @binding is not an option here
            if initialOverlayVisibility {
                openVoiceOverly()
            }
            shuffleSuggestions()
        }
        .navigationBarHidden(true)
        .background(Color.backgroundPrimary.ignoresSafeArea())
    }
    
    func openVoiceOverly() {
        MicPermitionHelper.requestAuthorization(status: {  status in
            if status == false {
                showMicAccessAlert = true
            } else {
                self.isOverlayVisible = true
            }
        })
    }
    
    func shuffleSuggestions() {
        picks = Array(allSuggestions.shuffled().prefix(4))
    }
    
    func getBottomProxyCount() -> Int {
        chatViewModel.isLLMActive ? chatViewModel.chatHistory.count : (chatViewModel.chatHistory.count - 1)
    }
}


struct CustomTextField: View {
    @Binding var text: String
    let placeholder: String
    @FocusState var isFocused: Bool
    
    var body: some View {
        
        
        HStack {
            TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.textPrimary.opacity(0.4)))
                .focused($isFocused)
                .foregroundColor(.textPrimary)
                .frame(height: 52)
                .modifier(PlaceholderTextModifier(color: .white))
            
            }
    }
}



struct PlaceholderTextModifier: ViewModifier {
    var color: Color
    
    func body(content: Content) -> some View {
        content
            .foregroundColor(color)
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("How can I help you today?")
                .font(.title2)
                .multilineTextAlignment(.center)
            Text("You can use Nimble AI while being completely offline. Give it a try!")
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}
