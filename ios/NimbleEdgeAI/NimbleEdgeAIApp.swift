/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI
import NimbleNetiOS
import Firebase
import StoreKit

@main
struct NimbleEdgeAIApp: App {
    @State private var isDownloadComplete = false
    @State private var isLLMDownloaded = UserDefaults.standard.bool(forKey: "isLLMDownloaded")
    @State private var showDownloadPage = false
    @State private var showInitialisationFailureAlert = false
    @State private var showAppNotSupportedAlert = false
    @State private var showRateAlert = false

    // Rate Us variable
    @AppStorage("hasAlreadyRatedApp") private var hasAlreadyRatedApp = false


    init() {
        //FirebaseApp.configure()
        initializeNimbeNet()
    }

    var body: some Scene {
        WindowGroup {
            if isLLMDownloaded {
                ContentView()
                    .onAppear {
                        initialise()
                        loadFillerAudioInMemory()
                        if shouldShowRateUsAlert() {
                            showRateAlert = true
                        }
                    }
                    .alert(ErrorConstants.initializeErrorMessage, isPresented: $showInitialisationFailureAlert) {
                        Button("Retry") { initialise() }
                    }
                    .alert("Enjoying the app?", isPresented: $showRateAlert) {
                        Button("Rate Us") {
                            if let scene = UIApplication.shared.connectedScenes
                                .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                                AppStore.requestReview(in: scene)
                                hasAlreadyRatedApp = true // assuming here user will give the rating here
                            }
                        }
                        Button("Not Now", role: .cancel) { }
                    }
            } else {
                if !showDownloadPage {
                    IntroductionPage {
                        initialise()
                        showDownloadPage = true
                    }
                    .alert(ErrorConstants.appNotSupportedInThisDevice, isPresented: $showAppNotSupportedAlert) {
                        Button("Cancel") { showAppNotSupportedAlert = false }
                    }
                    .alert(ErrorConstants.initializeErrorMessage, isPresented: $showInitialisationFailureAlert) {
                        Button("Retry") { initialise() }
                    }
                } else {
                    DownloadingView(progressManager: .init(files: DownloadItem.getDefaultDownloadItem()), onDownloadCompleted: {
                        UserDefaults.standard.set(true, forKey: "isLLMDownloaded")
                        isLLMDownloaded = true
                    })
                }
            }
        }
    }

    func shouldShowRateUsAlert() -> Bool {

        // storing date of installation in UD
        if UserDefaults.standard.object(forKey: "installDate") == nil {
            UserDefaults.standard.set(Date(), forKey: "installDate")
        }

        guard let installDate = UserDefaults.standard.object(forKey: "installDate") as? Date else {
            return false
        }

        let calendar = Calendar.current
        let currentDate = Date()

        // Calculate days between install and now
        guard let daysSinceInstall = calendar.dateComponents([.day], from: installDate, to: currentDate).day else {
            return false
        }

        // checking if days since install is geometric progression of 3
        guard daysSinceInstall % 3 == 0 else { return false }
        var x = daysSinceInstall / 3
        return (x != 0) && ((x & (x - 1)) == 0)
    }

    func initialise() {
        setupEspeakCallbacks()
        if DeviceIdentification.getDeviceTier() == .three {
            showAppNotSupportedAlert = true
        } else {
            let initialiseStatus = initializeNimbeNet()
            showInitialisationFailureAlert = !initialiseStatus
        }
    }
}

@discardableResult
func initializeNimbeNet() -> Bool {
    setupEspeakCallbacks()

    let compatibilityTag = DeviceIdentification.getDeviceTier() == .two ? NimbleNetSettings.lowerTierCompatibilityTag : NimbleNetSettings.compatibilityTag

    let nimbleNetConfig = NimbleNetConfig(clientId: NimbleNetSettings.clientID,
                                          clientSecret: NimbleNetSettings.clientSecret,
                                          host: NimbleNetSettings.host,
                                          deviceId: NimbleNetSettings.deviceId,
                                          debug: NimbleNetSettings.debug,
                                          compatibilityTag: compatibilityTag)

    return NimbleNetApi.initialize(config: nimbleNetConfig).status
}

func setupEspeakCallbacks() {
    let espeakNGContext = EspeakNGService.shared
    EspeakNGCallbacks.initializeEspeakCallback = espeakNGContext.set_espeak_initialize_callback
    EspeakNGCallbacks.espeakTextToPhonemesCallback = espeakNGContext.set_espeak_text_to_phonemes_callback
}

class GlobalState {
    static var fillerAudios: [[Int32]] = []
}

func loadFillerAudioInMemory() {
    if let path = Bundle.main.path(forResource: "filler_voice_pcms", ofType: "json") {
        do {
            let jsonText = try String(contentsOfFile: path, encoding: .utf8)

            if let data = jsonText.data(using: .utf8) {
                let decoder = JSONDecoder()
                let fillerAudios = try decoder.decode([[Int32]].self, from: data)
                GlobalState.fillerAudios = fillerAudios
                debugPrint("Reading JSON for filler Audio succeeded")

            }
        } catch {
            debugPrint("Error reading the JSON for filler Audio: \(error)")
        }
    }
}
