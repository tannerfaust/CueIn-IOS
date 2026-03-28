//
//  Formula.swift
//  CueIn
//
//  Domain model for formulas — predefined day schedules.
//

import Foundation

struct CategoryAllocation: Identifiable {
    let category: BlockCategory
    let duration: TimeInterval
    let totalDuration: TimeInterval

    var id: String { category.rawValue }

    var percentage: Double {
        guard totalDuration > 0 else { return 0 }
        return duration / totalDuration
    }

    var percentageLabel: String {
        "\(Int((percentage * 100).rounded()))%"
    }
}

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

// MARK: - Time Magnet

struct TimeMagnetSettings: Codable, Equatable {
    var isEnabled: Bool

    static let disabled = TimeMagnetSettings()

    init(isEnabled: Bool = false) {
        self.isEnabled = isEnabled
    }

    func interval(for priority: BlockPriority) -> TimeInterval {
        switch priority {
        case .high:
            return 30 * 60
        case .medium:
            return 15 * 60
        case .low:
            return 10 * 60
        }
    }
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
    var timeMagnet: TimeMagnetSettings
    
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

    var categoryAllocations: [CategoryAllocation] {
        blocks.categoryAllocations()
    }

    var isTimeMagnetEnabled: Bool {
        type == .full && timeMagnet.isEnabled
    }
    
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
        emoji: String = "⚡",
        timeMagnet: TimeMagnetSettings = .disabled
    ) {
        self.id = id
        self.name = name
        self.targetDuration = targetDuration
        self.blocks = blocks
        self.type = type
        self.status = status
        self.emoji = emoji
        self.timeMagnet = timeMagnet
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case targetDuration
        case blocks
        case type
        case status
        case emoji
        case timeMagnet
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        targetDuration = try container.decode(TimeInterval.self, forKey: .targetDuration)
        blocks = try container.decode([Block].self, forKey: .blocks)
        type = try container.decode(FormulaType.self, forKey: .type)
        status = try container.decode(FormulaStatus.self, forKey: .status)
        emoji = try container.decode(String.self, forKey: .emoji)
        timeMagnet = try container.decodeIfPresent(TimeMagnetSettings.self, forKey: .timeMagnet) ?? .disabled
    }
}

extension Collection where Element == Block {
    func categoryAllocations(totalDuration: TimeInterval? = nil) -> [CategoryAllocation] {
        let totals = reduce(into: [BlockCategory: TimeInterval]()) { partialResult, block in
            partialResult[block.category, default: 0] += block.duration
        }

        let resolvedTotal = totalDuration ?? totals.values.reduce(0, +)

        return BlockCategory.allCases.compactMap { category in
            guard let duration = totals[category], duration > 0 else { return nil }
            return CategoryAllocation(
                category: category,
                duration: duration,
                totalDuration: resolvedTotal
            )
        }
    }
}
