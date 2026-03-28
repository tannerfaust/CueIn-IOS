//
//  Category.swift
//  CueIn
//
//  Domain model for block categories and subcategories.
//

import SwiftUI

// MARK: - Block Category

enum BlockCategory: String, Codable, CaseIterable, Identifiable {
    case work
    case sport
    case study
    case wellness
    case custom
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .work:     return "Work"
        case .sport:    return "Sport"
        case .study:    return "Study"
        case .wellness: return "Wellness"
        case .custom:   return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .work:     return "briefcase.fill"
        case .sport:    return "figure.run"
        case .study:    return "book.fill"
        case .wellness: return "heart.fill"
        case .custom:   return "star.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .work:     return Theme.categoryWork
        case .sport:    return Theme.categorySport
        case .study:    return Theme.categoryStudy
        case .wellness: return Theme.categoryWellness
        case .custom:   return Theme.categoryCustom
        }
    }

    var defaultColorHex: String {
        switch self {
        case .work:     return "0A84FF"
        case .sport:    return "32D74B"
        case .study:    return "BF5AF2"
        case .wellness: return "FF9F0A"
        case .custom:   return "64D2FF"
        }
    }
    
    /// Default subcategories for each category
    var defaultSubcategories: [String] {
        switch self {
        case .work:     return ["Deep Work", "Shallow Work", "Creative Work", "Meetings"]
        case .sport:    return ["Cardio", "Boxing", "Stretching", "Resistance Training"]
        case .study:    return ["Computer Science", "Math", "Physics", "Languages"]
        case .wellness: return ["Meditation", "Cold Shower", "Journaling", "Breathing"]
        case .custom:   return []
        }
    }
}
