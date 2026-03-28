//
//  Theme.swift
//  CueIn
//
//  Design system — clean dark theme. Colors used only as functional accents.
//

import SwiftUI
import UIKit

enum AppearanceMode: String, CaseIterable, Identifiable {
    static let storageKey = "appearanceMode"

    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

enum TodayProgressDisplayMode: String, CaseIterable, Identifiable {
    static let storageKey = "todayProgressDisplayMode"

    case elapsed
    case remaining

    var id: String { rawValue }

    var title: String {
        switch self {
        case .elapsed: return "Passed %"
        case .remaining: return "Left %"
        }
    }

    var summaryLabel: String {
        switch self {
        case .elapsed: return "passed"
        case .remaining: return "left"
        }
    }
}

enum CommitmentRatingSetting {
    static let storageKey = "commitmentRatingEnabled"
    static let defaultValue = true
}

enum TimeMagnetSetting {
    static let storageKey = "timeMagnetEnabled"
    static let defaultValue = true
}

enum ScheduleOverrunSetting {
    static let storageKey = "expandDayForOverrun"
    static let defaultValue = false
}

enum LazyStartSetting {
    static let enabledStorageKey = "lazyStartEnabled"
    static let thresholdStorageKey = "lazyStartThresholdSeconds"
    static let defaultEnabled = true
    static let defaultThresholdSeconds: Double = 13 * 3600
}

enum ExecutionControlsSetting {
    static let storageKey = "executionControlsEnabled"
    static let defaultValue = true
}

enum IncompleteDayMetricsSetting {
    static let storageKey = "saveMetricsWithoutCompletion"
    static let defaultValue = false
}

enum OvertimeCheckInSetting {
    static let enabledStorageKey = "overtimeCheckInEnabled"
    static let limitStorageKey = "overtimeCheckInLimitSeconds"
    static let defaultEnabled = false
    static let defaultLimitSeconds: Double = 3600
    static let limitOptions: [Double] = [15 * 60, 30 * 60, 60 * 60, 2 * 3600]

    static func title(for seconds: Double) -> String {
        let totalMinutes = Int(seconds / 60)
        if totalMinutes >= 60 {
            let hours = totalMinutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        return "\(totalMinutes) min"
    }
}

// MARK: - Theme

enum Theme {
    
    // MARK: - Background Colors (true dark, no purple tints)
    
    static let backgroundPrimary   = Color.dynamic(light: "F4F1EA", dark: "000000")
    static let backgroundSecondary = Color.dynamic(light: "FAF8F2", dark: "0F0F0F")
    static let backgroundTertiary  = Color.dynamic(light: "ECE8DE", dark: "1A1A1A")
    static let backgroundCard      = Color.dynamic(light: "FFFFFF", dark: "141414")
    static let backgroundElevated  = Color.dynamic(light: "F1EEE6", dark: "1F1F1F")
    
    // MARK: - Accent (clean white / neutral — no purple)
    
    static let accent              = Color.dynamic(light: "111111", dark: "FFFFFF")
    static let accentSecondary     = Color.dynamic(light: "6F6F73", dark: "A0A0A0")
    static let onAccent            = Color.dynamic(light: "FFFFFF", dark: "000000")
    static let selectionBackground = accent
    static let selectionForeground = onAccent
    
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentSecondary],
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
    
    static let textPrimary   = Color.dynamic(light: "111111", dark: "FFFFFF")
    static let textSecondary = Color.dynamic(light: "5E5F66", dark: "8E8E93")
    static let textTertiary  = Color.dynamic(light: "8C8D94", dark: "48484A")
    
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
    
    static let divider = Color.dynamic(light: "D8D3C8", dark: "2C2C2E")
    static let surfaceStroke = textPrimary.opacity(0.08)
    static let glassStroke = textPrimary.opacity(0.08)
    static let tabBarOverlay = backgroundSecondary.opacity(0.82)
    static let tabBarHairline = textPrimary.opacity(0.06)
}

// MARK: - Color Extension (Hex Init)

extension Color {
    static func dynamic(light: String, dark: String) -> Color {
        Color(
            uiColor: UIColor { traitCollection in
                UIColor(hex: traitCollection.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }

    init(hex: String) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: String) {
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
            red: CGFloat(r) / 255,
            green: CGFloat(g) / 255,
            blue: CGFloat(b) / 255,
            alpha: CGFloat(a) / 255
        )
    }
}
