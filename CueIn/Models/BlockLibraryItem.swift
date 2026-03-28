//
//  BlockLibraryItem.swift
//  CueIn
//
//  Reusable saved block template.
//

import Foundation

struct BlockLibraryItem: Identifiable, Codable {
    let id: UUID
    var name: String
    var duration: TimeInterval
    var category: BlockCategory
    var subcategory: String
    var priority: BlockPriority
    var flowLogic: FlowLogic
    var colorHex: String
    var details: String
    var miniFormulaId: UUID?
    var fixedStartSecondsFromMidnight: TimeInterval?
    var isTimeframeFixed: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        duration: TimeInterval,
        category: BlockCategory,
        subcategory: String = "",
        priority: BlockPriority = .medium,
        flowLogic: FlowLogic = .flowing,
        colorHex: String,
        details: String = "",
        miniFormulaId: UUID? = nil,
        fixedStartSecondsFromMidnight: TimeInterval? = nil,
        isTimeframeFixed: Bool = false,
        createdAt: Date = Date()
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
        self.miniFormulaId = miniFormulaId
        self.fixedStartSecondsFromMidnight = fixedStartSecondsFromMidnight
        self.isTimeframeFixed = isTimeframeFixed
        self.createdAt = createdAt
    }

    init(block: Block, id: UUID = UUID(), createdAt: Date = Date()) {
        self.init(
            id: id,
            name: block.name,
            duration: block.duration,
            category: block.category,
            subcategory: block.subcategory,
            priority: block.priority,
            flowLogic: block.flowLogic,
            colorHex: block.colorHex,
            details: block.details,
            miniFormulaId: block.miniFormulaId,
            fixedStartSecondsFromMidnight: block.fixedStartSecondsFromMidnight,
            isTimeframeFixed: block.isTimeframeFixed,
            createdAt: createdAt
        )
    }

    func makeBlock() -> Block {
        Block(
            name: name,
            duration: duration,
            category: category,
            subcategory: subcategory,
            priority: priority,
            flowLogic: flowLogic,
            colorHex: colorHex,
            details: details,
            miniFormulaId: miniFormulaId,
            fixedStartSecondsFromMidnight: fixedStartSecondsFromMidnight,
            isTimeframeFixed: isTimeframeFixed
        )
    }

    func matches(_ other: BlockLibraryItem) -> Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(
            other.name.trimmingCharacters(in: .whitespacesAndNewlines)
        ) == .orderedSame
        && abs(duration - other.duration) < 1
        && category == other.category
        && subcategory.trimmingCharacters(in: .whitespacesAndNewlines).localizedCaseInsensitiveCompare(
            other.subcategory.trimmingCharacters(in: .whitespacesAndNewlines)
        ) == .orderedSame
        && priority == other.priority
        && flowLogic == other.flowLogic
        && miniFormulaId == other.miniFormulaId
        && fixedStartSecondsFromMidnight == other.fixedStartSecondsFromMidnight
        && isTimeframeFixed == other.isTimeframeFixed
    }
}
