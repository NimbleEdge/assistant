/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation

class DeviceIdentification {
    
    static func getDeviceTier() -> DeviceTier {
        var systemInfo = utsname()
        uname(&systemInfo)
        
        let identifier = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        } ?? "unknown"
        
        // Simulators (Intel or Apple Silicon)
        if identifier == "x86_64" || identifier == "arm64" {
            return .one
        }
        
        // iPhone check
        if identifier.hasPrefix("iPhone") {
            if let model = iPhoneModel(identifier: identifier) {
                switch model {
                case .belowIPhone10:
                    return .three
                case .iPhone10To12:
                    return .two
                case .aboveIPhone12:
                    return .one
                }
            }
        }
        
        // iPads with M1 or M2 chips
        let mSeriesIPads: Set<String> = [
            "iPad13,4", "iPad13,5", "iPad13,6", "iPad13,7",
            "iPad13,8", "iPad13,9", "iPad13,10", "iPad13,11",
            "iPad14,3", "iPad14,4",
            "iPad14,5", "iPad14,6"
        ]
        
        if identifier.hasPrefix("iPad") {
            // Return false if iPad has no M1/M2 chip (Tier 3)
            return mSeriesIPads.contains(identifier) ? .one : .three
        }
        
        // All other cases (e.g., unknown devices)
        return .three
    }
    
    private static func iPhoneModel(identifier: String) -> iPhoneModels? {
        switch identifier {
        case "iPhone1,1", "iPhone1,2", "iPhone2,1", "iPhone3,1", "iPhone3,2", "iPhone3,3":
            return .belowIPhone10
        case "iPhone7,1", "iPhone7,2", "iPhone8,1", "iPhone8,2", "iPhone8,4", "iPhone9,1", "iPhone9,2", "iPhone9,3", "iPhone9,4":
            return .iPhone10To12
        case let model where model.compare("iPhone10,", options: .numeric) == .orderedDescending:
            return .aboveIPhone12
        default:
            return nil
        }
    }
    
    private enum iPhoneModels {
        case belowIPhone10
        case iPhone10To12
        case aboveIPhone12
    }
}

enum DeviceTier {
    case one
    case two
    case three
}
