//
//  UserProfile.swift
//  CueIn
//
//  Domain model for user profile — stages, goals, strategy.
//

import Foundation

// MARK: - Goal

struct Goal: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var category: BlockCategory?
    var isCompleted: Bool
    var createdAt: Date
    
    init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        category: BlockCategory? = nil,
        isCompleted: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.category = category
        self.isCompleted = isCompleted
        self.createdAt = createdAt
    }
}

// MARK: - User Profile

struct UserProfile: Codable {
    var stageName: String               // Current life phase (e.g. "College", "Career Growth")
    var goals: [Goal]
    var dailyTargetHours: Int           // Default 16
    
    init(
        stageName: String = "Getting Started",
        goals: [Goal] = [],
        dailyTargetHours: Int = 16
    ) {
        self.stageName = stageName
        self.goals = goals
        self.dailyTargetHours = dailyTargetHours
    }
}
