//
//  Formula.swift
//  CueIn
//
//  Domain model for formulas — predefined day schedules.
//

import Foundation

// MARK: - Formula Type

enum FormulaType: String, Codable, CaseIterable, Identifiable {
    case full   // Covers an entire day
    case mini   // Sub-schedule that lives inside a block
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .full: return "Full Formula"
        case .mini: return "Mini-Formula"
        }
    }
}

// MARK: - Formula Status

enum FormulaStatus: String, Codable {
    case active
    case inactive
}

// MARK: - Formula

struct Formula: Identifiable, Codable {
    let id: UUID
    var name: String
    var targetDuration: TimeInterval    // seconds (default 16 * 3600)
    var blocks: [Block]
    var type: FormulaType
    var status: FormulaStatus
    var emoji: String                   // visual identifier
    
    // MARK: - Computed
    
    /// Total duration of all blocks combined
    var totalBlocksDuration: TimeInterval {
        blocks.reduce(0) { $0 + $1.duration }
    }
    
    /// How much of the target is filled by blocks
    var fillPercentage: Double {
        guard targetDuration > 0 else { return 0 }
        return totalBlocksDuration / targetDuration
    }
    
    /// Remaining unscheduled time
    var unscheduledTime: TimeInterval {
        max(0, targetDuration - totalBlocksDuration)
    }
    
    var blockCount: Int { blocks.count }
    
    var formattedTargetDuration: String {
        let hours = Int(targetDuration) / 3600
        return "\(hours)h"
    }
    
    // MARK: - Init
    
    init(
        id: UUID = UUID(),
        name: String,
        targetDuration: TimeInterval = 16 * 3600,
        blocks: [Block] = [],
        type: FormulaType = .full,
        status: FormulaStatus = .active,
        emoji: String = "⚡"
    ) {
        self.id = id
        self.name = name
        self.targetDuration = targetDuration
        self.blocks = blocks
        self.type = type
        self.status = status
        self.emoji = emoji
    }
}
