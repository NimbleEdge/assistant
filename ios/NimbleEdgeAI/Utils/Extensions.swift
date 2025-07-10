/*
 * SPDX-FileCopyrightText: (C) 2025 DeliteAI Authors
 *
 * SPDX-License-Identifier: Apache-2.0
 */

import Foundation
import SwiftUI
import UIKit

extension String {
    func height(withConstrainedWidth width: CGFloat, font: UIFont) -> CGFloat {
        let constraintRect = CGSize(width: width, height: .greatestFiniteMagnitude)
        let boundingBox = self.boundingRect(with: constraintRect,
                                              options: .usesLineFragmentOrigin,
                                              attributes: [.font: font],
                                              context: nil)
        return ceil(boundingBox.height)
    }
}


extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}

extension Color {
    static let backgroundPrimary = Color(hex: 0x030712)
    static let backgroundSecondary = Color(hex: 0x10131C)

    static let textPrimary = Color(hex: 0xFFFFFF)
    static let textSecondary = Color(hex: 0x9A9CA0)
    static let textTertiary = Color(hex: 0x777777)

    static let accent = Color(hex: 0x16ADB9)
    static let accentHigh1 = Color(hex: 0x45BDC7)
    static let accentHigh2 = Color(hex: 0xB7E6E9)
    static let accentLow1 = Color(hex: 0x09494E)
    static let accentLow2 = Color(hex: 0x041E20)
}

extension Color {
    init(hex: UInt32) {
        let red = Double((hex >> 16) & 0xff) / 255.0
        let green = Double((hex >> 8) & 0xff) / 255.0
        let blue = Double(hex & 0xff) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}

extension Font {
    static let materialTitleLarge = Font.system(size: 22, weight: .regular)
    static let materialBodyLarge = Font.system(size: 18, weight: .regular)
    static let materialBodyMedium = Font.system(size: 16, weight: .regular)
    static let materialBodySmall = Font.system(size: 14, weight: .regular)
}

extension Int64 {
    func asReadableSize(unit: ByteCountFormatter.Units = [.useMB, .useGB]) -> String {
        if self == 0 { return "0 MB" }
        let byteCountFormatter = ByteCountFormatter()
        byteCountFormatter.allowedUnits = unit
        byteCountFormatter.countStyle = .decimal
        return byteCountFormatter.string(fromByteCount: self)
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

extension FixedWidthInteger {
    func littleEndianData() -> Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}

extension Error {
    var localizedMessage: String {
        return self.localizedDescription
    }
}
