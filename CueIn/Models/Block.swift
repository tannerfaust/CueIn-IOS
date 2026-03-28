//
//  Block.swift
//  CueIn
//
//  Domain model for schedule blocks — the atoms of a formula.
//

import SwiftUI

// MARK: - Flow Logic

/// Controls what happens when a block's time runs out.
enum FlowLogic: String, Codable, CaseIterable, Identifiable {
    /// Type 1: Schedule keeps moving regardless of check-off.
    case flowing
    /// Type 2: Block stays active until checked off, postponing everything.
    case blocking
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .flowing:  return "Flowing"
        case .blocking: return "Blocking"
        }
    }
    
    var description: String {
        switch self {
        case .flowing:  return "Next block starts when time is up, even if unchecked"
        case .blocking: return "Block stays until you check it off"
        }
    }
}

// MARK: - Block Priority

enum BlockPriority: Int, Codable, CaseIterable, Comparable, Identifiable {
    case low = 1
    case medium = 2
    case high = 3
    
    var id: Int { rawValue }
    
    var displayName: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }
    
    static func < (lhs: BlockPriority, rhs: BlockPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Block

struct Block: Identifiable, Codable {
    let id: UUID
    var name: String
    var duration: TimeInterval          // seconds
    var category: BlockCategory
    var subcategory: String
    var priority: BlockPriority
    var flowLogic: FlowLogic
    var colorHex: String                // stored as hex; rendered via Theme
    var details: String
    var isChecked: Bool
    var commitmentRating: Int?
    var isSmallRepeatable: Bool
    var repeatInterval: TimeInterval?   // seconds between repeats (nil = no repeat)
    
    /// Optional nested mini-formula (blocks inside blocks)
    var miniFormulaId: UUID?

    /// Resolved mini-formula tasks for the active day/runtime state.
    var miniBlocks: [Block]?
    
    /// Optional scheduled real-world time
    var scheduledTime: Date?

    /// Optional fixed clock time for recurring formulas.
    var fixedStartSecondsFromMidnight: TimeInterval?

    /// Protect this block's duration from automatic recalibration.
    var isTimeframeFixed: Bool
    
    // MARK: - Runtime State
    
    var elapsedTime: TimeInterval = 0
    
    var remainingTime: TimeInterval {
        max(0, duration - elapsedTime)
    }
    
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, elapsedTime / duration)
    }
    
    var isOverrun: Bool {
        elapsedTime > duration
    }
    
    // MARK: - Init
    
    init(
        id: UUID = UUID(),
        name: String,
        duration: TimeInterval,
        category: BlockCategory = .custom,
        subcategory: String = "",
        priority: BlockPriority = .medium,
        flowLogic: FlowLogic = .flowing,
        colorHex: String = "6C63FF",
        details: String = "",
        isChecked: Bool = false,
        commitmentRating: Int? = nil,
        isSmallRepeatable: Bool = false,
        repeatInterval: TimeInterval? = nil,
        miniFormulaId: UUID? = nil,
        miniBlocks: [Block]? = nil,
        scheduledTime: Date? = nil,
        fixedStartSecondsFromMidnight: TimeInterval? = nil,
        isTimeframeFixed: Bool = false
    ) {
        self.id = id
        self.name = name
        self.duration = duration
        self.category = category
        self.subcategory = subcategory
        self.priority = priority
        self.flowLogic = flowLogic
        self.colorHex = colorHex
        self.details = details
        self.isChecked = isChecked
        self.commitmentRating = commitmentRating
        self.isSmallRepeatable = isSmallRepeatable
        self.repeatInterval = repeatInterval
        self.miniFormulaId = miniFormulaId
        self.miniBlocks = miniBlocks
        self.scheduledTime = scheduledTime
        self.fixedStartSecondsFromMidnight = fixedStartSecondsFromMidnight
        self.isTimeframeFixed = isTimeframeFixed
    }
    
    // MARK: - Codable (skip runtime state)
    
    enum CodingKeys: String, CodingKey {
        case id, name, duration, category, subcategory, priority, flowLogic
        case colorHex, details, isChecked, commitmentRating, isSmallRepeatable, repeatInterval, miniFormulaId, miniBlocks, scheduledTime, fixedStartSecondsFromMidnight, isTimeframeFixed, elapsedTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        category = try container.decode(BlockCategory.self, forKey: .category)
        subcategory = try container.decodeIfPresent(String.self, forKey: .subcategory) ?? ""
        priority = try container.decodeIfPresent(BlockPriority.self, forKey: .priority) ?? .medium
        flowLogic = try container.decodeIfPresent(FlowLogic.self, forKey: .flowLogic) ?? .flowing
        colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex) ?? "6C63FF"
        details = try container.decodeIfPresent(String.self, forKey: .details) ?? ""
        isChecked = try container.decodeIfPresent(Bool.self, forKey: .isChecked) ?? false
        commitmentRating = try container.decodeIfPresent(Int.self, forKey: .commitmentRating)
        isSmallRepeatable = try container.decodeIfPresent(Bool.self, forKey: .isSmallRepeatable) ?? false
        repeatInterval = try container.decodeIfPresent(TimeInterval.self, forKey: .repeatInterval)
        miniFormulaId = try container.decodeIfPresent(UUID.self, forKey: .miniFormulaId)
        miniBlocks = try container.decodeIfPresent([Block].self, forKey: .miniBlocks)
        scheduledTime = try container.decodeIfPresent(Date.self, forKey: .scheduledTime)
        fixedStartSecondsFromMidnight = try container.decodeIfPresent(TimeInterval.self, forKey: .fixedStartSecondsFromMidnight)
        isTimeframeFixed = try container.decodeIfPresent(Bool.self, forKey: .isTimeframeFixed) ?? false
        elapsedTime = try container.decodeIfPresent(TimeInterval.self, forKey: .elapsedTime) ?? 0
    }
}

// MARK: - Formatted Helpers

extension Block {
    var hasFixedStartTime: Bool {
        fixedStartSecondsFromMidnight != nil || scheduledTime != nil
    }

    var hasMiniFormula: Bool {
        miniFormulaId != nil || miniTaskCount > 0
    }

    var miniTaskCount: Int {
        miniBlocks?.count ?? 0
    }

    var completedMiniTaskCount: Int {
        miniBlocks?.filter(\.isChecked).count ?? 0
    }

    var allMiniTasksChecked: Bool {
        guard let miniBlocks, !miniBlocks.isEmpty else { return false }
        return miniBlocks.allSatisfy(\.isChecked)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(minutes)m"
    }
    
    var formattedRemaining: String {
        let total = Int(isOverrun ? (elapsedTime - duration) : remainingTime)
        let m = total / 60
        let s = total % 60
        return isOverrun
            ? String(format: "+%d:%02d", m, s)
            : String(format: "%d:%02d", m, s)
    }
    
    var categoryColor: Color {
        category.color
    }
}
