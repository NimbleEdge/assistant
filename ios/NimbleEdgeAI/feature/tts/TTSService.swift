/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class TTSService {
    static func passLexiconToTheWorkflowScript(lexiconJson: [String:Any]) throws {
        try TTSManager.passLexiconToTheWorkflowScript(lexiconJson: lexiconJson)
    }

    static func getPCM(input: String) throws ->[Float] {
        try TTSManager.getPCM(input:input)
    }
}
