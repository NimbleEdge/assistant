/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import DeliteAI
class LLMService {
    func feedInput(input: String, isVoiceInitiated: Bool = false) async throws {
        try await LLMManager.feedInput(input: input, isVoiceInitiated: isVoiceInitiated)
    }

    func getNextMap() async throws ->  [String: NimbleNetTensor] {
        try await LLMManager.getNextMap()
    }
    func stopLLM ()  throws{
        try LLMManager.stopLLM()
    }
}
