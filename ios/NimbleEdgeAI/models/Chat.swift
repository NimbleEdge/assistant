/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct Chat: Codable {
    let messages: [ChatMessage]
    let id: String

    func toString()-> String {
        let encoder = JSONEncoder()
        if let jsonData = try? encoder.encode(self),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return "{}"
    }

    static func fromString(_ str: String) -> Chat? {
        let decoder = JSONDecoder()
        if let jsonData = str.data(using: .utf8),
           let chat = try? decoder.decode(Chat.self, from: jsonData) {
            return chat
        }
        return nil
    }
}
