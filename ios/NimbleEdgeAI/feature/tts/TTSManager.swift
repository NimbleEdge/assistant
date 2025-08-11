/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import DeliteAI

class TTSManager {
    // Used only during the app init
    static func passLexiconToTheWorkflowScript(lexiconJson: [String: Any]) throws {
        let result = NimbleNetApi.runMethod(methodName:
            "init",
            inputs: [
                "lexicon": NimbleNetTensor(
                    data: lexiconJson, datatype: .json, shape: nil
                )
            ]
        )
        guard result.status else {
            throw NSError(domain: "NimbleEdge", code: 1, userInfo: [NSLocalizedDescriptionKey: "NimbleNet.runMethod('init') failed with status: \(result.status)"])
        }
    }

    static func getPCM(input: String) throws -> [Float] {
        let ttsresult = NimbleNetApi.runMethod(
            methodName: "run_model",
            inputs: [
                "text": NimbleNetTensor(
                    data: input,
                    datatype: .string,
                    shape: nil
                )
            ]
        )
        
        if ttsresult.status == false {
            //TODO: Make this better
            throw NSError(domain: "TTSresult failed", code: 0)
        }
        
        let pcm: [Float] = ttsresult.payload?["audio"]?.data as? [Float] ?? []
        return pcm
    }
}
