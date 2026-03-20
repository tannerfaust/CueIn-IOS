//
//  QSEntry.swift
//  CueIn
//
//  Domain model for Quantifiable Self data rows.
//

import Foundation

// MARK: - QS Input Type

enum QSInputType: String, Codable, CaseIterable, Identifiable {
    case time
    case number
    case boolean
    case text
    case options
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .time:    return "Time"
        case .number:  return "Number"
        case .boolean: return "Yes / No"
        case .text:    return "Text"
        case .options: return "Multiple Choice"
        }
    }
    
    var icon: String {
        switch self {
        case .time:    return "clock"
        case .number:  return "number"
        case .boolean: return "checkmark.circle"
        case .text:    return "text.alignleft"
        case .options: return "list.bullet"
        }
    }
}

// MARK: - QS Notification Trigger

enum QSNotificationTrigger: String, Codable {
    case onFirstLog     // Pop-up on first app open of the day
    case scheduled      // At a user-set time
    case none           // Manual access only
}

// MARK: - QS Automation

enum QSAutomation: String, Codable {
    case automatic      // Captured by app events (e.g. Start → wake-up time)
    case proactive      // User manually enters
    
    var displayName: String {
        switch self {
        case .automatic: return "Auto"
        case .proactive: return "Manual"
        }
    }
}

// MARK: - QS Entry (Definition)

/// Defines a trackable metric row — the "template" for what to track.
struct QSEntry: Identifiable, Codable {
    let id: UUID
    var name: String
    var inputType: QSInputType
    var trigger: QSNotificationTrigger
    var automation: QSAutomation
    var options: [String]               // For .options type
    var defaultTrue: Bool               // For .boolean — default state is "true"
    var icon: String
    
    init(
        id: UUID = UUID(),
        name: String,
        inputType: QSInputType = .number,
        trigger: QSNotificationTrigger = .none,
        automation: QSAutomation = .proactive,
        options: [String] = [],
        defaultTrue: Bool = false,
        icon: String = "circle"
    ) {
        self.id = id
        self.name = name
        self.inputType = inputType
        self.trigger = trigger
        self.automation = automation
        self.options = options
        self.defaultTrue = defaultTrue
        self.icon = icon
    }
}

// MARK: - QS Record (Daily Value)

/// A single day's value for a QS entry.
struct QSRecord: Identifiable, Codable {
    let id: UUID
    var entryId: UUID
    var entryName: String
    var date: Date
    var value: String       // Stored as string; parsed by input type
    
    init(id: UUID = UUID(), entryId: UUID, entryName: String = "", value: String = "", date: Date = Date()) {
        self.id = id
        self.entryId = entryId
        self.entryName = entryName
        self.date = date
        self.value = value
    }
}
