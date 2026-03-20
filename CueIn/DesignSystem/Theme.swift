//
//  Theme.swift
//  CueIn
//
//  Design system — clean dark theme. Colors used only as functional accents.
//

import SwiftUI

// MARK: - Theme

enum Theme {
    
    // MARK: - Background Colors (true dark, no purple tints)
    
    static let backgroundPrimary   = Color(hex: "000000")
    static let backgroundSecondary = Color(hex: "0F0F0F")
    static let backgroundTertiary  = Color(hex: "1A1A1A")
    static let backgroundCard      = Color(hex: "141414")
    static let backgroundElevated  = Color(hex: "1F1F1F")
    
    // MARK: - Accent (clean white / neutral — no purple)
    
    static let accent              = Color.white
    static let accentSecondary     = Color(hex: "A0A0A0")
    
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color.white, Color(hex: "C0C0C0")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    // MARK: - Semantic Colors (functional only)
    
    static let success   = Color(hex: "32D74B")   // iOS green
    static let warning   = Color(hex: "FFD60A")   // iOS yellow
    static let error     = Color(hex: "FF453A")   // iOS red
    static let info      = Color(hex: "64D2FF")   // iOS cyan
    
    // MARK: - Text Colors
    
    static let textPrimary   = Color.white
    static let textSecondary = Color(hex: "8E8E93")  // iOS secondary label
    static let textTertiary  = Color(hex: "48484A")  // iOS tertiary label
    
    // MARK: - Category Colors (the ONLY colors in the app — used as accents)
    
    static let categoryWork     = Color(hex: "0A84FF")   // blue
    static let categorySport    = Color(hex: "32D74B")   // green
    static let categoryStudy    = Color(hex: "BF5AF2")   // purple (category only)
    static let categoryWellness = Color(hex: "FF9F0A")   // orange
    static let categoryCustom   = Color(hex: "64D2FF")   // cyan
    
    // MARK: - Typography (SF Pro, system default)
    
    static func heading1() -> Font { .system(size: 28, weight: .bold) }
    static func heading2() -> Font { .system(size: 22, weight: .semibold) }
    static func heading3() -> Font { .system(size: 18, weight: .semibold) }
    static func body1() -> Font    { .system(size: 16, weight: .regular) }
    static func body2() -> Font    { .system(size: 14, weight: .regular) }
    static func caption() -> Font  { .system(size: 12, weight: .medium) }
    static func mono() -> Font     { .system(size: 14, weight: .medium, design: .monospaced) }
    
    // MARK: - Spacing
    
    static let spacingXS: CGFloat  = 4
    static let spacingSM: CGFloat  = 8
    static let spacingMD: CGFloat  = 16
    static let spacingLG: CGFloat  = 24
    static let spacingXL: CGFloat  = 32
    
    // MARK: - Corner Radius
    
    static let radiusSM: CGFloat = 8
    static let radiusMD: CGFloat = 12
    static let radiusLG: CGFloat = 16
    static let radiusXL: CGFloat = 20
    
    // MARK: - Divider
    
    static let divider = Color(hex: "2C2C2E")
}

// MARK: - Color Extension (Hex Init)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 128, 128, 128)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
