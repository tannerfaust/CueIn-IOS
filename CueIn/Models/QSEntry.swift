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
    case journal
    case options
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .time:    return "Time"
        case .number:  return "Number"
        case .boolean: return "Yes / No"
        case .text:    return "Text"
        case .journal: return "Journal"
        case .options: return "Multiple Choice"
        }
    }
    
    var icon: String {
        switch self {
        case .time:    return "clock"
        case .number:  return "number"
        case .boolean: return "checkmark.circle"
        case .text:    return "text.alignleft"
        case .journal: return "book.closed"
        case .options: return "list.bullet"
        }
    }
}

// MARK: - Legacy Trigger

enum QSNotificationTrigger: String, Codable {
    case onFirstLog     // Pop-up on first app open of the day
    case scheduled      // At a user-set time
    case none           // Manual access only
}

// MARK: - QS Trigger Settings

enum QSTriggerKind: String, Codable, CaseIterable, Identifiable {
    case manual
    case scheduledTime
    case formulaStart
    case formulaEnd
    case afterFinalBlock

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: return "Manual Only"
        case .scheduledTime: return "At a Time"
        case .formulaStart: return "Formula Start"
        case .formulaEnd: return "Formula End"
        case .afterFinalBlock: return "After Final Block"
        }
    }

    var description: String {
        switch self {
        case .manual:
            return "No reminders. You fill it only when you want."
        case .scheduledTime:
            return "A reminder at a chosen time if today's input is still empty."
        case .formulaStart:
            return "A reminder right when your day schedule starts."
        case .formulaEnd:
            return "A reminder at the planned end of today's schedule."
        case .afterFinalBlock:
            return "A reminder once the last block in today's formula is done."
        }
    }
}

struct QSTriggerSettings: Codable, Equatable {
    var isEnabled: Bool
    var kind: QSTriggerKind
    var scheduledSecondsFromMidnight: Double

    init(
        isEnabled: Bool = false,
        kind: QSTriggerKind = .manual,
        scheduledSecondsFromMidnight: Double = 21 * 3600
    ) {
        self.isEnabled = isEnabled
        self.kind = kind
        self.scheduledSecondsFromMidnight = scheduledSecondsFromMidnight
    }

    static let none = QSTriggerSettings()
    static let evening = QSTriggerSettings(isEnabled: true, kind: .scheduledTime, scheduledSecondsFromMidnight: 21 * 3600)
    static let morning = QSTriggerSettings(isEnabled: true, kind: .scheduledTime, scheduledSecondsFromMidnight: 8 * 3600)
    static let formulaStart = QSTriggerSettings(isEnabled: true, kind: .formulaStart)
    static let formulaEnd = QSTriggerSettings(isEnabled: true, kind: .formulaEnd)
    static let finalBlock = QSTriggerSettings(isEnabled: true, kind: .afterFinalBlock)

    var summary: String {
        guard isEnabled else { return "Manual only" }

        switch kind {
        case .manual:
            return "Manual only"
        case .scheduledTime:
            let seconds = max(0, scheduledSecondsFromMidnight)
            let hours = Int(seconds) / 3600
            let minutes = (Int(seconds) % 3600) / 60
            return String(format: "At %02d:%02d", hours, minutes)
        case .formulaStart:
            return "At formula start"
        case .formulaEnd:
            return "At formula end"
        case .afterFinalBlock:
            return "After final block"
        }
    }
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
    var trigger: QSTriggerSettings
    var automation: QSAutomation
    var options: [String]               // For .options type
    var defaultTrue: Bool               // For .boolean — default state is "true"
    var icon: String
    
    init(
        id: UUID = UUID(),
        name: String,
        inputType: QSInputType = .number,
        trigger: QSTriggerSettings = .none,
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

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case inputType
        case trigger
        case automation
        case options
        case defaultTrue
        case icon
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        inputType = try container.decode(QSInputType.self, forKey: .inputType)

        if let triggerSettings = try? container.decode(QSTriggerSettings.self, forKey: .trigger) {
            trigger = triggerSettings
        } else if let legacyTrigger = try? container.decode(QSNotificationTrigger.self, forKey: .trigger) {
            switch legacyTrigger {
            case .none:
                trigger = .none
            case .scheduled:
                trigger = .evening
            case .onFirstLog:
                trigger = .formulaStart
            }
        } else {
            trigger = .none
        }

        automation = try container.decodeIfPresent(QSAutomation.self, forKey: .automation) ?? .proactive
        options = try container.decodeIfPresent([String].self, forKey: .options) ?? []
        defaultTrue = try container.decodeIfPresent(Bool.self, forKey: .defaultTrue) ?? false
        icon = try container.decodeIfPresent(String.self, forKey: .icon) ?? inputType.icon
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

struct QSJournalContent: Codable, Equatable {
    var text: String
    var photoFileNames: [String]

    init(text: String = "", photoFileNames: [String] = []) {
        self.text = text
        self.photoFileNames = photoFileNames
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photoFileNames.isEmpty
    }

    var previewText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return photoFileNames.isEmpty ? "No entry yet" : "\(photoFileNames.count) photo" + (photoFileNames.count == 1 ? "" : "s")
        }
        return trimmed
    }
}

struct QSPresetDefinition: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let entry: QSEntry
}

enum QSPresetLibrary {
    static let presets: [QSPresetDefinition] = [
        QSPresetDefinition(
            id: "journal",
            title: "Journal",
            subtitle: "Long-form reflection with photos at the end of the day",
            category: "Reflection",
            entry: QSEntry(name: "Journal", inputType: .journal, trigger: .finalBlock, automation: .proactive, icon: "book.closed")
        ),
        QSPresetDefinition(
            id: "gratitude",
            title: "Gratitude Notes",
            subtitle: "A short evening gratitude entry",
            category: "Reflection",
            entry: QSEntry(name: "Gratitude", inputType: .journal, trigger: .formulaEnd, automation: .proactive, icon: "heart.text.square")
        ),
        QSPresetDefinition(
            id: "mood",
            title: "Mood Check",
            subtitle: "Quick emotional state check-in",
            category: "Mind",
            entry: QSEntry(name: "Mood", inputType: .options, trigger: .formulaEnd, automation: .proactive, options: ["Excellent", "Good", "Okay", "Low", "Bad"], icon: "face.smiling")
        ),
        QSPresetDefinition(
            id: "energy",
            title: "Energy Level",
            subtitle: "How much energy you had during the day",
            category: "Mind",
            entry: QSEntry(name: "Energy", inputType: .options, trigger: .formulaStart, automation: .proactive, options: ["High", "Solid", "Flat", "Low"], icon: "bolt.heart")
        ),
        QSPresetDefinition(
            id: "sleep",
            title: "Sleep Duration",
            subtitle: "Track hours slept the night before",
            category: "Recovery",
            entry: QSEntry(name: "Sleep Duration", inputType: .number, trigger: .morning, automation: .proactive, icon: "moon.zzz")
        ),
        QSPresetDefinition(
            id: "wake",
            title: "Wake-up Time",
            subtitle: "Record what time the day actually started",
            category: "Recovery",
            entry: QSEntry(name: "Wake-up Time", inputType: .time, trigger: .formulaStart, automation: .automatic, icon: "sunrise")
        ),
        QSPresetDefinition(
            id: "water",
            title: "Water Intake",
            subtitle: "Daily hydration count",
            category: "Body",
            entry: QSEntry(name: "Water", inputType: .number, trigger: .evening, automation: .proactive, icon: "drop")
        ),
        QSPresetDefinition(
            id: "workout",
            title: "Workout Done",
            subtitle: "Simple yes/no training confirmation",
            category: "Body",
            entry: QSEntry(name: "Workout Done", inputType: .boolean, trigger: .finalBlock, automation: .proactive, icon: "figure.strengthtraining.traditional")
        ),
        QSPresetDefinition(
            id: "alcohol",
            title: "Alcohol-free Day",
            subtitle: "Binary habit check for the evening",
            category: "Habits",
            entry: QSEntry(name: "Alcohol-free", inputType: .boolean, trigger: .evening, automation: .proactive, defaultTrue: true, icon: "wineglass")
        ),
        QSPresetDefinition(
            id: "weight",
            title: "Weight",
            subtitle: "Morning body-weight log",
            category: "Body",
            entry: QSEntry(name: "Weight", inputType: .number, trigger: .morning, automation: .proactive, icon: "scalemass")
        )
    ]

    static var groupedPresets: [(category: String, presets: [QSPresetDefinition])] {
        Dictionary(grouping: presets, by: \.category)
            .map { (category: $0.key, presets: $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.category < $1.category }
    }
}
