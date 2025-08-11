/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import SwiftUI
import Combine
import Foundation
import DeliteAI

@MainActor
class MainViewModel: ObservableObject {
    var cacheRepository = CacheRepository()
    func hasUserEverClickedOnChat() -> Bool {
        return cacheRepository.hasUserEverClickedOnChat()
    }
    
    func registerUserTapToChat() {
        if (hasUserEverClickedOnChat()){ return }
        
        Task(priority: .background) {
            await cacheRepository.registerUserTapToChat()
        }
    }
    
}
