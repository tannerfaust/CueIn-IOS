//
//  DayLog.swift
//  CueIn
//
//  Domain model for daily tracking records.
//

import Foundation

// MARK: - Block Log Entry

/// Records how a single block was executed on a given day.
struct BlockLogEntry: Identifiable, Codable {
    let id: UUID
    var blockId: UUID
    var blockName: String
    var category: BlockCategory
    var subcategory: String
    var scheduledDuration: TimeInterval
    var actualDuration: TimeInterval
    var wasChecked: Bool
    var startedAt: Date?
    var completedAt: Date?
    
    init(
        id: UUID = UUID(),
        blockId: UUID,
        blockName: String,
        category: BlockCategory,
        subcategory: String = "",
        scheduledDuration: TimeInterval,
        actualDuration: TimeInterval = 0,
        wasChecked: Bool = false,
        startedAt: Date? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.blockId = blockId
        self.blockName = blockName
        self.category = category
        self.subcategory = subcategory
        self.scheduledDuration = scheduledDuration
        self.actualDuration = actualDuration
        self.wasChecked = wasChecked
        self.startedAt = startedAt
        self.completedAt = completedAt
    }
}

// MARK: - Day Log

/// A complete record of one day's formula execution.
struct DayLog: Identifiable, Codable {
    let id: UUID
    var date: Date
    var formulaId: UUID?
    var formulaName: String
    var blockLogs: [BlockLogEntry]
    var startedAt: Date?
    var targetDuration: TimeInterval
    
    // MARK: - Computed
    
    /// Adherence = checked blocks / total blocks (0.0 – 1.0)
    var adherence: Double {
        guard !blockLogs.isEmpty else { return 0 }
        let checked = blockLogs.filter(\.wasChecked).count
        return Double(checked) / Double(blockLogs.count)
    }
    
    /// Total actual time across all blocks
    var totalActualTime: TimeInterval {
        blockLogs.reduce(0) { $0 + $1.actualDuration }
    }
    
    /// Per-category durations
    var categoryDurations: [BlockCategory: TimeInterval] {
        var result: [BlockCategory: TimeInterval] = [:]
        for log in blockLogs {
            result[log.category, default: 0] += log.actualDuration
        }
        return result
    }
    
    /// Per-subcategory durations
    var subcategoryDurations: [String: TimeInterval] {
        var result: [String: TimeInterval] = [:]
        for log in blockLogs where !log.subcategory.isEmpty {
            result[log.subcategory, default: 0] += log.actualDuration
        }
        return result
    }
    
    init(
        id: UUID = UUID(),
        date: Date = Date(),
        formulaId: UUID? = nil,
        formulaName: String = "",
        blockLogs: [BlockLogEntry] = [],
        startedAt: Date? = nil,
        targetDuration: TimeInterval = 16 * 3600
    ) {
        self.id = id
        self.date = date
        self.formulaId = formulaId
        self.formulaName = formulaName
        self.blockLogs = blockLogs
        self.startedAt = startedAt
        self.targetDuration = targetDuration
    }
}
