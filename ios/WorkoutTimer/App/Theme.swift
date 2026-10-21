import SwiftUI
import UIKit

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }
}

extension Color {
    /// A color that switches between a light and a dark value with the system appearance.
    static func dynamic(_ light: UInt32, _ dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

/// Palette taken from the web version: white canvas, pastel blobs, orange / blue / lime / mustard accents, navy ink.
enum Palette {
    static let bg = Color.dynamic(0xFFFFFF, 0x121625)
    static let soft = Color.dynamic(0xF5F6FA, 0x1A1F32)
    static let fg = Color.dynamic(0x1B2440, 0xEEF0F7)
    static let muted = Color.dynamic(0x9398A8, 0x8C93A8)
    static let line = Color.dynamic(0xE4E6EE, 0x2A3049)

    static let orange = Color.dynamic(0xD9683B, 0xEC7849)
    static let orangeSoft = Color.dynamic(0xFCEEE7, 0x2D1F1D)

    static let green = Color.dynamic(0xA6E27A, 0x8FD860)
    static let greenSolid = Color.dynamic(0x86D359, 0x86D359)
    static let greenInk = Color.dynamic(0x4C9F2C, 0x9BE36A)
    static let greenSoft = Color.dynamic(0xF3FBEC, 0x18271D)
    static let onGreen = Color(UIColor(hex: 0x1B2440))
    static let mint = Color.dynamic(0x8BEA8D, 0x6FD873)
    static let blobMint = Color.dynamic(0x98F29B, 0x3F9E55)

    static let blue = Color.dynamic(0xA4C1EE, 0x7FA3E3)
    static let blueInk = Color.dynamic(0x5A84D0, 0x97B6EF)
    static let blueSoft = Color.dynamic(0xEFF4FC, 0x19223D)
    static let blobBlue = Color.dynamic(0xA4C1EE, 0x3D5A93)

    static let mustard = Color.dynamic(0xEBC352, 0xE9C055)
    static let mustardInk = Color.dynamic(0xBF8E17, 0xF0CB5E)
    static let mustardSoft = Color.dynamic(0xFDF7E5, 0x2A2518)

    static let ink = Color.dynamic(0x1B2440, 0xEEF0F7)
    static let inkFg = Color.dynamic(0xFFFFFF, 0x121625)
}

extension Font {
    static func display(_ size: CGFloat, _ weight: Font.Weight = .heavy) -> Font {
        .system(size: size, weight: weight, design: .default)
    }

    static func num(_ size: CGFloat, _ weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .default).monospacedDigit()
    }
}
