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
    
    init(id: UUID = UUID(), day: DayOfWeek, formulaIds: [UUID] = []) {
        self.id = id
        self.day = day
        self.formulaIds = formulaIds
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
    
    /// Set formula IDs for a specific day
    mutating func setFormulaIds(_ ids: [UUID], for day: DayOfWeek) {
        if let index = assignments.firstIndex(where: { $0.day == day }) {
            assignments[index].formulaIds = ids
        }
    }
}
