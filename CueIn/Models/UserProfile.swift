//
//  UserProfile.swift
//  CueIn
//
//  Domain model for user profile — stages, surges, strategy.
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

// MARK: - Surge

struct Surge: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var objective: String
    var focusCategories: [BlockCategory]
    var startDate: Date
    var endDate: Date
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        objective: String = "",
        focusCategories: [BlockCategory] = [],
        startDate: Date = Date(),
        endDate: Date,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.objective = objective
        self.focusCategories = focusCategories
        self.startDate = startDate
        self.endDate = endDate
        self.createdAt = createdAt
    }

    var normalizedFocusCategories: [BlockCategory] {
        Array(Set(focusCategories)).sorted { $0.rawValue < $1.rawValue }
    }

    var durationDays: Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = calendar.startOfDay(for: endDate)
        return max(1, (calendar.dateComponents([.day], from: start, to: end).day ?? 0) + 1)
    }

    func includes(_ date: Date, calendar: Calendar = .current) -> Bool {
        let day = calendar.startOfDay(for: date)
        return day >= calendar.startOfDay(for: startDate) && day <= calendar.startOfDay(for: endDate)
    }

    func isActive(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        includes(date, calendar: calendar)
    }

    func hasStarted(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: date) >= calendar.startOfDay(for: startDate)
    }

    func isFinished(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        calendar.startOfDay(for: date) > calendar.startOfDay(for: endDate)
    }
}

// MARK: - User Profile

struct UserProfile: Codable {
    var stageName: String               // Current life phase (e.g. "College", "Career Growth")
    var goals: [Goal]                   // Legacy goals, kept for migration/backward compatibility
    var surges: [Surge]
    var dailyTargetHours: Int           // Default 16
    
    init(
        stageName: String = "Getting Started",
        goals: [Goal] = [],
        surges: [Surge] = [],
        dailyTargetHours: Int = 16
    ) {
        self.stageName = stageName
        self.goals = goals
        self.surges = surges
        self.dailyTargetHours = dailyTargetHours
    }

    enum CodingKeys: String, CodingKey {
        case stageName
        case goals
        case surges
        case dailyTargetHours
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        stageName = try container.decodeIfPresent(String.self, forKey: .stageName) ?? "Getting Started"
        goals = try container.decodeIfPresent([Goal].self, forKey: .goals) ?? []
        surges = try container.decodeIfPresent([Surge].self, forKey: .surges) ?? []
        dailyTargetHours = try container.decodeIfPresent(Int.self, forKey: .dailyTargetHours) ?? 16
    }

    func activeSurges(on date: Date = Date()) -> [Surge] {
        surges.filter { $0.isActive(on: date) }
    }

    func preferredPriority(for category: BlockCategory, on date: Date = Date()) -> BlockPriority? {
        activeSurges(on: date)
            .contains(where: { $0.focusCategories.contains(category) }) ? .high : nil
    }
}
