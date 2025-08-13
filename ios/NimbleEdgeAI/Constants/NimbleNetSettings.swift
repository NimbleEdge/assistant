/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class NimbleNetSettings {
    public static var clientID: String {
        return Bundle.main.object(forInfoDictionaryKey: "NIMBLE_CLIENT_ID") as? String ?? ""
    }
    public static var clientSecret: String {
        return Bundle.main.object(forInfoDictionaryKey: "NIMBLE_CLIENT_SECRET") as? String ?? ""
    }
    public static var host: String {
        return ("https://" + (Bundle.main.object(forInfoDictionaryKey: "NIMBLE_HOST") as? String ?? ""))
    }
    public static var deviceId: String {
        return Bundle.main.object(forInfoDictionaryKey: "NIMBLE_DEVICE_ID") as? String ?? ""
    }
    public static var compatibilityTag: String {
        return Bundle.main.object(forInfoDictionaryKey: "NIMBLE_COMPATIBILITY_TAG") as? String ?? ""
    }
    public static var lowerTierCompatibilityTag: String {
        return Bundle.main.object(forInfoDictionaryKey: "NIMBLE_LOWER_TIER_COMPATIBILITY_TAG") as? String ?? ""
    }
    public static var debug: Bool = false
}
