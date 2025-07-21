/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import NimbleNetiOS
class LLMService {
    func feedInput(input: String) async throws {
        await try LLMManager.feedInput(input: input)
    }

    func getNextMap() async -> [String: NimbleNetTensor] {
        await LLMManager.getNextMap()
    }
    func stopLLM ()  throws{
        try LLMManager.stopLLM()
    }
}
