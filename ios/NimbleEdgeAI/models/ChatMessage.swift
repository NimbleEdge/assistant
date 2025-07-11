/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

struct ChatMessage: Codable {
    var message: String?
    let isUserMessage: Bool
    let timestamp: Date
    let tps: Float
}
