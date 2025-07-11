/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */
 
import SwiftUI

@available(iOS 16.0, *)
struct ContentView: View {
    @State private var navigate = false
    @State private var path = NavigationPath()
    let mainViewModel = MainViewModel()
    let historyViewModel = HistoryViewModel()
    var chatViewModel = ChatViewModel()
    
    init(){
        loadJSONFile(named: "lexicon") { json in
            guard let lexiconJson = json else {
                print("Failed to load JSON")
                return
            }
            
            do {
                let ttsService = TTSService()
                try TTSService.passLexiconToTheWorkflowScript(lexiconJson: lexiconJson)
            } catch {
                print("Error passing lexicon to workflow script: \(error)")
            }
        }
    }
    
    
    var body: some View {
        NavigationStack(path: $path) {
            HomeView(
                path: $path, mainViewModel: MainViewModel(),
                historyViewModel: HistoryViewModel())
            .navigationDestination(for: HomeDestination.self) { destination in
                switch destination {
                case .audioModeView:
                    ChatView(chatViewModel: chatViewModel, path: $path,isOverlayVisible: true)
                case .historyView:
                    HistoryView(historyViewModel: historyViewModel, chatViewModel: chatViewModel, path: $path)
                case .chatView:
                    ChatView(chatViewModel: chatViewModel, path: $path)
                case .chatViewWith(chatID: let chatID):
                    ChatView(chatViewModel: chatViewModel, path: $path, chatID: chatID)
                }
            }

        }
    }
}


func loadJSONFile(named fileName: String, completion: @escaping ([String: Any]?) -> Void) {
    DispatchQueue.global(qos: .background).async {
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            print("Could not find \(fileName).json in bundle")
            DispatchQueue.main.async {
                completion(nil)
            }
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
            DispatchQueue.main.async {
                completion(json)
            }
        } catch {
            print("Error loading or parsing JSON: \(error)")
            DispatchQueue.main.async {
                completion(nil)
            }
        }
    }
}
