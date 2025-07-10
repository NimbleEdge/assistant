/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI


@available(iOS 16.0, *)
struct HistoryView: View {
    @ObservedObject var historyViewModel: HistoryViewModel
    @ObservedObject var chatViewModel: ChatViewModel
    @State private var searchQuery = ""
    @Binding var path: NavigationPath
    
    var body: some View {
        VStack(spacing: 0) {
            
            // Custom Header View
            NETopBar(onAudioModeButtonPressed: {
                path.append(HomeDestination.audioModeView)
            }, title: "Your Conversations", path: $path)
            
            // List Content View
            VStack(spacing: 16) {
                Group {
                    if historyViewModel.chatHistory == nil {
                        // Loading state
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Color.accentHigh1))
                        Spacer()
                    } else if historyViewModel.chatHistory?.isEmpty ?? true {
                        // Empty state
                        Spacer()
                        VStack() {
                            Text("No History")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color.textPrimary)

                            Text("Start a new Conversation to see it here")
                                .foregroundColor(Color.textSecondary)
                                .font(.body)
                        }
                        Spacer()
                    } else {
                        
                        // Custom Search Bar
                        NESearchBar(text: $searchQuery)
                        .onChange(of: searchQuery) { _ in
                            historyViewModel.searchHistory(text: searchQuery)
                        }
                        .padding([.horizontal, .top], 20)                        
                        // History list
                        HistoryListContent(
                            historyViewModel: historyViewModel,
                            path: $path
                        )
                    }
                }
            }
        }
        .background(Color.backgroundPrimary)
        .navigationBarHidden(true)
        .onAppear {
            historyViewModel.updateChatHistory()
        }
        .contentShape(Rectangle())
    }
}

@available(iOS 16.0, *)
struct HistoryListContent: View {
    
    @ObservedObject var historyViewModel: HistoryViewModel
    @Binding var path: NavigationPath
    @State var deleteSelectedChatID: String?
    @State private var showConfirmDialog = false
    
    var body: some View {
        //Initializer for conditional binding must have Optional type, not '[HistoryItem]'
        ScrollView {
            VStack(spacing: 24) {
                ForEach((historyViewModel.chatHistoryFiltered), id: \.section) { category in
                    let items = category.history
                    
                    VStack() {
                        // Category header
                        HStack {
                            Rectangle()
                                .frame(height: 0.4)
                                .foregroundColor(Color.accentLow1)
                                .frame(maxWidth: .infinity)
                            
                            
                            Text(category.section)
                                .foregroundColor(Color.accent)
                                .font(.footnote)
                                .fontWeight(.semibold)
                                .foregroundColor(.black)
                                .padding(.horizontal, 8)
                                .fixedSize()
                            
                            Rectangle()
                                .frame(height: 0.4)
                                .foregroundColor(Color.accentLow1)
                                .frame(maxWidth: .infinity)
                            
                        }
                        .padding(.vertical, 0.5)
                        .padding(.horizontal, 20)
                        
                        
                        // History items in this category
                        ForEach(items, id: \.parentChatId) { item in
                            
                            //single history iteam
                            HistoryCardItem(
                                history: item,
                                onClick: {
                                    path.append(HomeDestination.chatViewWith(chatID: item.parentChatId))
                                }
                            )
                            .padding(.horizontal, 20)
                            .background(Color.backgroundPrimary)
                            .contextMenu {
                                Button(role: .destructive, action: {
                                    deleteSelectedChatID = item.parentChatId
                                    showConfirmDialog = true
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                            .padding(.bottom, 8)
                            
                        }
                        
                    }
                }
            }
        }
        .alert(isPresented: $showConfirmDialog) {
            Alert(
                title: Text("Are you sure you want to delete this chat?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let deleteSelectedChatID = deleteSelectedChatID {
                        historyViewModel.deleteChat(id: deleteSelectedChatID)
                    }
                },
                secondaryButton: .cancel(Text("Cancel"))
            )
        }
    }
}

struct HistoryCardItem: View {
    let history: HistoryItem
    let onClick: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(history.title)
                    .font(.subheadline)
                    .foregroundColor(Color.textPrimary)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Spacer().frame(height: 3)
                
                Text("\(formatDate(history.dateTime)) • \(formatTime(history.dateTime))")
                    .font(.caption)
                    .foregroundColor(Color.textSecondary)

            }

            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onClick()
        }

    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMMM, yyyy"
        return formatter.string(from: date)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}
