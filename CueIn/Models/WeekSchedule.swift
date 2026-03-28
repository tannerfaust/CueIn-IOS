//
//  WeekSchedule.swift
//  CueIn
//
//  Domain model for the 7-day formula mapping.
//

import Foundation

// MARK: - Day of Week

enum DayOfWeek: Int, Codable, CaseIterable, Identifiable, Comparable {
    case sunday = 0
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    
    var id: Int { rawValue }
    
    var shortName: String {
        switch self {
        case .sunday:    return "Sun"
        case .monday:    return "Mon"
        case .tuesday:   return "Tue"
        case .wednesday: return "Wed"
        case .thursday:  return "Thu"
        case .friday:    return "Fri"
        case .saturday:  return "Sat"
        }
    }

    var displayName: String {
        switch self {
        case .sunday:    return "Sunday"
        case .monday:    return "Monday"
        case .tuesday:   return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday:  return "Thursday"
        case .friday:    return "Friday"
        case .saturday:  return "Saturday"
        }
    }
    
    var initial: String {
        String(shortName.prefix(1))
    }
    
    static func < (lhs: DayOfWeek, rhs: DayOfWeek) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    /// Returns the DayOfWeek for today
    static var today: DayOfWeek {
        let weekday = Calendar.current.component(.weekday, from: Date())
        // Calendar weekday: 1 = Sunday, 2 = Monday, ...
        return DayOfWeek(rawValue: weekday - 1) ?? .sunday
    }
}

// MARK: - Day Assignment

struct DayAssignment: Identifiable, Codable {
    let id: UUID
    var day: DayOfWeek
    var formulaIds: [UUID]
    var title: String
    var details: String

    var resolvedTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? day.displayName : trimmed
    }

    init(
        id: UUID = UUID(),
        day: DayOfWeek,
        formulaIds: [UUID] = [],
        title: String = "",
        details: String = ""
    ) {
        self.id = id
        self.day = day
        self.formulaIds = formulaIds
        self.title = title
        self.details = details
    }

    enum CodingKeys: String, CodingKey {
        case id, day, formulaIds, title, details
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        day = try container.decode(DayOfWeek.self, forKey: .day)
        formulaIds = try container.decodeIfPresent([UUID].self, forKey: .formulaIds) ?? []
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
    }
}

// MARK: - Week Schedule

struct WeekSchedule: Identifiable, Codable {
    let id: UUID
    var name: String
    var assignments: [DayAssignment]
    var isActive: Bool
    
    init(
        id: UUID = UUID(),
        name: String = "My Week",
        assignments: [DayAssignment]? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.isActive = isActive
        
        // Default: create an assignment for each day
        self.assignments = assignments ?? DayOfWeek.allCases.map {
            DayAssignment(day: $0)
        }
    }
    
    /// Get formula IDs for a specific day
    func formulaIds(for day: DayOfWeek) -> [UUID] {
        assignments.first(where: { $0.day == day })?.formulaIds ?? []
    }

    func assignment(for day: DayOfWeek) -> DayAssignment? {
        assignments.first(where: { $0.day == day })
    }
    
    /// Set formula IDs for a specific day
    mutating func setFormulaIds(_ ids: [UUID], for day: DayOfWeek) {
        if let index = assignments.firstIndex(where: { $0.day == day }) {
            assignments[index].formulaIds = ids
        }
    }

    mutating func updateAssignment(
        for day: DayOfWeek,
        title: String,
        details: String,
        formulaIds: [UUID]
    ) {
        if let index = assignments.firstIndex(where: { $0.day == day }) {
            assignments[index].title = title
            assignments[index].details = details
            assignments[index].formulaIds = formulaIds
        }
    }
}
