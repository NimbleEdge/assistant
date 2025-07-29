/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import NimbleNetiOS
class LLMManager {
    static func feedInput(input: String) async throws {
        let methodInput: [String: NimbleNetTensor] = [
            "query":  NimbleNetTensor(data: input, datatype: .string, shape: nil)

        ]
        let res = NimbleNetApi.runMethod(methodName: "prompt_llm", inputs: methodInput)
        if res.status == false {
            throw NSError(domain: "prompt_llm status false", code: 1)
        }
    }
    static func getNextMap() async throws -> [String: NimbleNetTensor] {
        let emptyInput: [String: NimbleNetTensor] = [:]
        let res = NimbleNetApi.runMethod(methodName: "get_next_str", inputs: emptyInput)
        if !res.status {
            throw NSError(domain: "get_next_str status false", code: 1)
        }

        guard let outputData = res.payload else {
            print("Error: No payload received")
            return [:]
        }

        var result: [String: NimbleNetTensor] = [:]
        for (key, tensorInternal) in outputData.map {
            result[key] = NimbleNetTensor(
                data: tensorInternal.data,
                datatype: tensorInternal.type,
                shape: tensorInternal.shape
            )
        }

        return result
    }
    static func stopLLM() throws{
        let result = NimbleNetApi.runMethod(methodName: "llm_cancel", inputs: [:])
    }
}
