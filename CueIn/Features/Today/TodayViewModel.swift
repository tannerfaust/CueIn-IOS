//
//  TodayViewModel.swift
//  CueIn
//
//  State management for the Today tab.
//  Persistent formula, duration control, monitoring, notifications.
//

import Foundation
import Combine
import SwiftUI

class TodayViewModel: ObservableObject {
    private static let selectedFormulaOverrideIDKey = "com.cuein.todaySelectedFormulaOverrideID"
    private static let selectedFormulaOverrideDayKey = "com.cuein.todaySelectedFormulaOverrideDay"
    
    @Published var engine: FormulaEngine
    @Published var isStarted: Bool = false
    @Published var showRoadblockSheet: Bool = false
    @Published var showAddTaskSheet: Bool = false
    @Published var showChangeFormula: Bool = false
    @Published var showNewFormula: Bool = false
    @Published var formulaName: String = ""
    @Published var stageName: String = ""
    @Published var showRealTime: Bool = false
    
    var dataStore: DataStore
    private var cancellables = Set<AnyCancellable>()
    
    init(dataStore: DataStore, engine: FormulaEngine) {
        self.dataStore = dataStore
        self.engine = engine
        self.stageName = dataStore.profile.stageName
        
        // Check if engine already restored from UserDefaults
        if engine.isRunning {
            if archiveStaleRunIfNeeded() {
                DispatchQueue.main.async { [weak self] in
                    self?.loadTodayFormula()
                }
            } else {
                self.isStarted = true
                self.formulaName = engine.formulaName
            }
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.loadTodayFormula()
            }
        }
        
        engine.$isRunning
            .receive(on: DispatchQueue.main)
            .sink { [weak self] running in
                self?.isStarted = running
            }
            .store(in: &cancellables)
    }
    
    func loadTodayFormula() {
        if let formula = resolvedTodayFormula() {
            engine.loadFormula(formula, expandingWith: dataStore)
            formulaName = formula.name
        } else {
            clearToday()
        }
    }

    func resetToday() {
        persistIncompleteMetricsIfEnabled()
        engine.clearToday()
        loadTodayFormula()
    }

    func clearToday() {
        persistIncompleteMetricsIfEnabled()
        clearSelectedFormulaOverride()
        engine.clearToday()
        formulaName = ""
    }
    
    func startDay() {
        engine.start()
    }

    func startDay(endingAt endDate: Date) {
        let duration = max(30 * 60, endDate.timeIntervalSince(Date()))
        engine.recalibrateBeforeStart(toTargetDuration: duration)
        engine.start()
    }
    
    func stopDay() {
        persistDayMetrics(force: true)
        clearSelectedFormulaOverride()
        engine.stop()
    }

    func selectTodayFormula(_ formula: Formula) {
        persistSelectedFormulaOverride(formula.id)
        engine.loadFormula(formula, expandingWith: dataStore)
        formulaName = formula.name
    }
    
    func toggleBlockCheck(at index: Int) {
        engine.toggleBlockCheck(at: index)
    }

    func toggleExecutionMode() {
        engine.toggleExecutionMode()
    }

    func setExecutionModeEnabled(_ isEnabled: Bool) {
        engine.setExecutionModeEnabled(isEnabled)
    }

    func startExecutingBlock(at index: Int) {
        engine.startExecutingBlock(at: index)
    }

    func playBlockNow(withId id: UUID) {
        guard let index = blockIndex(for: id) else { return }
        engine.playBlockNow(at: index)
    }

    func stopExecutingBlock() {
        engine.stopExecutingBlock()
    }

    func completeExecutingBlock() {
        engine.completeExecutingBlock()
    }
    
    func removeBlock(at index: Int) {
        guard index >= 0, index < engine.blocks.count else { return }
        let removedID = engine.blocks[index].id
        let currentID = engine.currentBlock?.id

        engine.blocks.remove(at: index)
        syncCurrentBlockIndex(using: currentID)

        if engine.executingBlockID == removedID {
            engine.stopExecutingBlock()
        } else {
            engine.syncRuntimeArtifacts()
        }
    }

    func blockIndex(for id: UUID) -> Int? {
        engine.blocks.firstIndex(where: { $0.id == id })
    }

    func removeBlock(withId id: UUID) {
        guard let index = blockIndex(for: id) else { return }
        removeBlock(at: index)
    }

    func updateBlock(_ block: Block) {
        guard let index = blockIndex(for: block.id) else { return }
        engine.blocks[index] = block
        engine.extendDayIfNeededForExplicitScheduleEdit()
    }

    func updateCommitmentRating(_ rating: Int?, forBlockWithID id: UUID) {
        engine.updateCommitmentRating(rating, forBlockWithID: id)
    }

    func duplicateBlock(withId id: UUID) {
        guard let index = blockIndex(for: id), engine.blocks.indices.contains(index) else { return }

        let source = engine.blocks[index]
        let copy = Block(
            name: source.name + " Copy",
            duration: source.duration,
            category: source.category,
            subcategory: source.subcategory,
            priority: source.priority,
            flowLogic: source.flowLogic,
            colorHex: source.colorHex,
            details: source.details,
            isChecked: false,
            commitmentRating: nil,
            isSmallRepeatable: source.isSmallRepeatable,
            repeatInterval: source.repeatInterval,
            miniFormulaId: source.miniFormulaId,
            miniBlocks: resolvedMiniFormulaBlock(from: source).miniBlocks,
            scheduledTime: source.scheduledTime,
            fixedStartSecondsFromMidnight: source.fixedStartSecondsFromMidnight,
            isTimeframeFixed: source.isTimeframeFixed
        )

        engine.blocks.insert(copy, at: index + 1)
        engine.syncRuntimeArtifacts()
    }

    func moveBlock(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        engine.moveBlocksAndRestartFlow(fromOffsets: offsets, toOffset: destination)
    }

    func checkMiniBlock(at blockIndex: Int, miniTaskIndex: Int) {
        engine.checkMiniBlock(at: blockIndex, miniTaskIndex: miniTaskIndex)
    }

    func toggleCurrentBlockPause() {
        engine.toggleCurrentBlockPause()
    }

    var currentTodayFormula: Formula? {
        guard let formulaId = engine.formulaId else { return nil }
        return dataStore.formula(for: formulaId)
    }

    var supportsTodayTimeMagnet: Bool {
        currentTodayFormula?.type == .full
    }

    func toggleTodayTimeMagnet() {
        guard var formula = currentTodayFormula, formula.type == .full else { return }
        formula.timeMagnet.isEnabled.toggle()
        dataStore.updateFormula(formula)
        engine.timeMagnet = formula.timeMagnet
        engine.syncRuntimeArtifacts()
    }

    var availableMiniFormulas: [Formula] {
        dataStore.formulas.filter { $0.type == .mini }
    }

    func suggestedPriority(for category: BlockCategory) -> BlockPriority {
        dataStore.preferredPriority(for: category) ?? .medium
    }
    
    func triggerRoadblock() {
        showRoadblockSheet = true
    }
    
    func addTask(name: String, duration: TimeInterval, flowLogic: FlowLogic, category: BlockCategory, scheduledTime: Date? = nil) {
        var task = Block(
            name: name,
            duration: duration,
            category: category,
            priority: dataStore.preferredPriority(for: category) ?? .medium,
            flowLogic: flowLogic
        )
        task.scheduledTime = scheduledTime
        
        if let time = scheduledTime {
            let insertIndex = findInsertIndex(for: time)
            engine.insertTask(task, at: insertIndex)
        } else {
            engine.insertTask(task)
        }
        showAddTaskSheet = false
    }

    func addBlockFromTodayWorkshop(
        name: String,
        duration: TimeInterval,
        category: BlockCategory,
        subcategory: String,
        priority: BlockPriority,
        flowLogic: FlowLogic,
        miniFormulaId: UUID?,
        insertAfterCurrent: Bool
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        var block = Block(
            name: trimmedName,
            duration: duration,
            category: category,
            subcategory: subcategory.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: priority,
            flowLogic: flowLogic,
            colorHex: category.defaultColorHex,
            miniFormulaId: miniFormulaId
        )

        if miniFormulaId != nil {
            block = resolvedMiniFormulaBlock(from: block)
        }

        let insertIndex: Int
        if insertAfterCurrent {
            if engine.blocks.isEmpty {
                insertIndex = 0
            } else {
                insertIndex = min(engine.blocks.count, max(engine.currentBlockIndex + 1, engine.totalChecked))
            }
        } else {
            insertIndex = engine.blocks.count
        }

        engine.insertTask(block, at: insertIndex)

        if formulaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            formulaName = "Today Draft"
            engine.formulaName = formulaName
        }
    }

    @discardableResult
    func saveTodayAsNewFormula(name: String, emoji: String) -> Formula? {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return nil }

        let sourceFormula = currentTodayFormula
        let normalizedBlocks = engine.blocks.map { block in
            Block(
                name: block.name,
                duration: block.duration,
                category: block.category,
                subcategory: block.subcategory,
                priority: block.priority,
                flowLogic: block.flowLogic,
                colorHex: block.colorHex,
                details: block.details,
                isChecked: false,
                commitmentRating: nil,
                isSmallRepeatable: block.isSmallRepeatable,
                repeatInterval: block.repeatInterval,
                miniFormulaId: block.miniFormulaId,
                miniBlocks: nil,
                scheduledTime: block.scheduledTime,
                fixedStartSecondsFromMidnight: block.fixedStartSecondsFromMidnight,
                isTimeframeFixed: block.isTimeframeFixed
            )
        }

        let savedFormula = Formula(
            name: trimmedName,
            targetDuration: max(engine.targetDuration, normalizedBlocks.reduce(0.0) { $0 + $1.duration }),
            blocks: normalizedBlocks,
            type: .full,
            status: .active,
            emoji: emoji.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? (sourceFormula?.emoji ?? "⚡") : emoji,
            timeMagnet: sourceFormula?.timeMagnet ?? engine.timeMagnet
        )

        dataStore.addFormula(savedFormula)
        return savedFormula
    }
    
    /// Add task that overrides current block immediately
    func addTaskNow(name: String, duration: TimeInterval, category: BlockCategory) {
        let task = Block(
            name: name,
            duration: duration,
            category: category,
            priority: .high,
            flowLogic: .blocking
        )
        engine.insertTaskNow(task)
        showRoadblockSheet = false
    }

    func recoverForgottenFormula(followRatio: Double, continueTodayFormula: Bool) {
        engine.recoverForgottenProgress(
            followRatio: followRatio,
            continueRunning: continueTodayFormula
        )
        showRoadblockSheet = false
    }
    
    // MARK: - Duration Control (before start)
    
    func changeDuration(_ hours: Double) {
        engine.setPreStartDuration(hours * 3600)
    }
    
    /// Estimated end time if formula starts now
    var estimatedEndTimeIfStartNow: String {
        let end = Date().addingTimeInterval(engine.targetDuration)
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: end)
    }
    
    /// Estimated end time for running formula
    var runningEndTime: String? {
        engine.formattedEndTime
    }
    
    // MARK: - Helpers
    
    private func findInsertIndex(for time: Date) -> Int? {
        guard let startDate = engine.startDate else { return nil }
        let targetOffset = time.timeIntervalSince(startDate)
        
        var accumulated: TimeInterval = 0
        for (index, block) in engine.blocks.enumerated() {
            accumulated += block.duration
            if accumulated >= targetOffset {
                return index + 1
            }
        }
        return nil
    }
    
    func realTimeLabel(for index: Int) -> String? {
        guard engine.blocks.indices.contains(index) else { return nil }

        let block = engine.blocks[index]

        if let fixedTime = fixedClockLabel(for: block) {
            return fixedTime
        }

        guard let startDate = engine.startDate, showRealTime else { return nil }
        
        var offset: TimeInterval = 0
        for i in 0..<index {
            offset += engine.blocks[i].duration
        }
        
        let blockTime = startDate.addingTimeInterval(offset)
        return formattedClockTime(blockTime)
    }
    
    func tuneIntoFlow() {
        if let miniFormula = dataStore.formulas.first(where: { $0.type == .mini }) {
            let flowBlock = resolvedMiniFormulaBlock(
                from: Block(
                name: "🌊 " + miniFormula.name,
                duration: miniFormula.blocks.reduce(0) { $0 + $1.duration },
                category: .wellness,
                priority: .medium,
                flowLogic: .blocking,
                miniFormulaId: miniFormula.id
                )
            )
            engine.insertTask(flowBlock)
        }
        showRoadblockSheet = false
    }

    func resolvedMiniFormulaBlock(from block: Block) -> Block {
        resolvedMiniFormulaBlock(from: block, visitedFormulaIDs: [])
    }

    private func resolvedMiniFormulaBlock(from block: Block, visitedFormulaIDs: Set<UUID>) -> Block {
        guard let miniFormulaId = block.miniFormulaId,
              let miniFormula = dataStore.formula(for: miniFormulaId),
              !visitedFormulaIDs.contains(miniFormulaId) else {
            var resolved = block
            resolved.commitmentRating = nil
            resolved.miniBlocks = block.miniBlocks?.map {
                var miniBlock = resolvedMiniFormulaBlock(from: $0, visitedFormulaIDs: visitedFormulaIDs)
                miniBlock.isChecked = false
                miniBlock.commitmentRating = nil
                return miniBlock
            }
            return resolved
        }

        var resolved = block
        resolved.commitmentRating = nil
        resolved.miniBlocks = miniFormula.blocks.map {
            resolvedMiniFormulaBlock(
                from: $0,
                visitedFormulaIDs: visitedFormulaIDs.union([miniFormulaId])
            )
        }
        return resolved
    }

    private func syncCurrentBlockIndex(using currentBlockID: UUID?) {
        guard !engine.blocks.isEmpty else {
            engine.currentBlockIndex = 0
            return
        }

        if let currentBlockID,
           let updatedIndex = engine.blocks.firstIndex(where: { $0.id == currentBlockID }) {
            engine.currentBlockIndex = updatedIndex
        } else {
            engine.currentBlockIndex = min(engine.currentBlockIndex, engine.blocks.count - 1)
        }
    }

    private var savesMetricsWithoutCompletion: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: IncompleteDayMetricsSetting.storageKey) != nil else {
            return IncompleteDayMetricsSetting.defaultValue
        }
        return defaults.bool(forKey: IncompleteDayMetricsSetting.storageKey)
    }

    private func resolvedTodayFormula() -> Formula? {
        if let overrideFormula = selectedFormulaOverride() {
            return overrideFormula
        }

        return dataStore.todayFormula()
    }

    private func selectedFormulaOverride() -> Formula? {
        let defaults = UserDefaults.standard
        guard let overrideIDString = defaults.string(forKey: Self.selectedFormulaOverrideIDKey),
              let overrideID = UUID(uuidString: overrideIDString),
              let savedDay = defaults.object(forKey: Self.selectedFormulaOverrideDayKey) as? Double else {
            return nil
        }

        let savedDate = Date(timeIntervalSince1970: savedDay)
        guard Calendar.current.isDate(savedDate, inSameDayAs: Date()) else {
            clearSelectedFormulaOverride()
            return nil
        }

        guard let formula = dataStore.formula(for: overrideID) else {
            clearSelectedFormulaOverride()
            return nil
        }

        return formula
    }

    private func persistSelectedFormulaOverride(_ id: UUID) {
        let defaults = UserDefaults.standard
        defaults.set(id.uuidString, forKey: Self.selectedFormulaOverrideIDKey)
        defaults.set(Calendar.current.startOfDay(for: Date()).timeIntervalSince1970, forKey: Self.selectedFormulaOverrideDayKey)
    }

    private func clearSelectedFormulaOverride() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: Self.selectedFormulaOverrideIDKey)
        defaults.removeObject(forKey: Self.selectedFormulaOverrideDayKey)
    }

    private func archiveStaleRunIfNeeded() -> Bool {
        guard savesMetricsWithoutCompletion,
              let sessionStart = engine.startDate,
              !Calendar.current.isDate(sessionStart, inSameDayAs: Date()) else {
            return false
        }

        persistDayMetrics(force: false)
        clearSelectedFormulaOverride()
        engine.clearToday()
        formulaName = ""
        return true
    }

    private func persistIncompleteMetricsIfEnabled() {
        guard savesMetricsWithoutCompletion else { return }
        persistDayMetrics(force: false)
    }

    private func persistDayMetrics(force: Bool) {
        guard shouldPersistDayMetrics(force: force) else { return }
        let log = engine.generateDayLog()
        dataStore.addDayLog(log)
    }

    private func shouldPersistDayMetrics(force: Bool) -> Bool {
        guard engine.startDate != nil, !engine.blocks.isEmpty else { return false }

        if force {
            return true
        }

        if engine.elapsedTotal > 0 {
            return true
        }

        return engine.blocks.contains { block in
            block.isChecked || block.elapsedTime > 0 || block.commitmentRating != nil
        }
    }

    private func fixedClockLabel(for block: Block) -> String? {
        if let fixedStartSeconds = block.fixedStartSecondsFromMidnight {
            let midnight = Calendar.current.startOfDay(for: Date())
            let fixedDate = midnight.addingTimeInterval(fixedStartSeconds)
            return formattedClockTime(fixedDate)
        }

        if let scheduledTime = block.scheduledTime {
            return formattedClockTime(scheduledTime)
        }

        return nil
    }

    private func formattedClockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
