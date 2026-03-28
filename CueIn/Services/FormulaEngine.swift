//
//  FormulaEngine.swift
//  CueIn
//
//  Runs the active formula — timers, flow logic, rebalancing.
//  PERSISTENT: saves state to UserDefaults, survives app close.
//  On reopen, recalculates position based on real-world time.
//

import Foundation
import Combine
import UIKit
import UserNotifications

// MARK: - Persisted State

struct PersistedFormulaState: Codable {
    var formulaId: UUID?
    var formulaName: String
    var blocks: [Block]
    var startDate: Date
    var targetDuration: TimeInterval
    var isRunning: Bool
    var currentBlockIndex: Int
    var elapsedTotal: TimeInterval
    var accumulatedPausedDuration: TimeInterval
    var pauseStartedAt: Date?
    var isExecutionModeEnabled: Bool
    var executingBlockID: UUID?
    var executionStartedAt: Date?
    var timeMagnet: TimeMagnetSettings
    var overtimePromptedBlockIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case formulaId
        case formulaName
        case blocks
        case startDate
        case targetDuration
        case isRunning
        case currentBlockIndex
        case elapsedTotal
        case accumulatedPausedDuration
        case pauseStartedAt
        case isExecutionModeEnabled
        case executingBlockID
        case executionStartedAt
        case timeMagnet
        case overtimePromptedBlockIDs
    }

    init(
        formulaId: UUID?,
        formulaName: String,
        blocks: [Block],
        startDate: Date,
        targetDuration: TimeInterval,
        isRunning: Bool,
        currentBlockIndex: Int,
        elapsedTotal: TimeInterval,
        accumulatedPausedDuration: TimeInterval,
        pauseStartedAt: Date?,
        isExecutionModeEnabled: Bool,
        executingBlockID: UUID?,
        executionStartedAt: Date?,
        timeMagnet: TimeMagnetSettings,
        overtimePromptedBlockIDs: [UUID]
    ) {
        self.formulaId = formulaId
        self.formulaName = formulaName
        self.blocks = blocks
        self.startDate = startDate
        self.targetDuration = targetDuration
        self.isRunning = isRunning
        self.currentBlockIndex = currentBlockIndex
        self.elapsedTotal = elapsedTotal
        self.accumulatedPausedDuration = accumulatedPausedDuration
        self.pauseStartedAt = pauseStartedAt
        self.isExecutionModeEnabled = isExecutionModeEnabled
        self.executingBlockID = executingBlockID
        self.executionStartedAt = executionStartedAt
        self.timeMagnet = timeMagnet
        self.overtimePromptedBlockIDs = overtimePromptedBlockIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        formulaId = try container.decodeIfPresent(UUID.self, forKey: .formulaId)
        formulaName = try container.decode(String.self, forKey: .formulaName)
        blocks = try container.decode([Block].self, forKey: .blocks)
        startDate = try container.decode(Date.self, forKey: .startDate)
        targetDuration = try container.decode(TimeInterval.self, forKey: .targetDuration)
        isRunning = try container.decode(Bool.self, forKey: .isRunning)
        currentBlockIndex = try container.decode(Int.self, forKey: .currentBlockIndex)
        elapsedTotal = try container.decode(TimeInterval.self, forKey: .elapsedTotal)
        accumulatedPausedDuration = try container.decode(TimeInterval.self, forKey: .accumulatedPausedDuration)
        pauseStartedAt = try container.decodeIfPresent(Date.self, forKey: .pauseStartedAt)
        isExecutionModeEnabled = try container.decode(Bool.self, forKey: .isExecutionModeEnabled)
        executingBlockID = try container.decodeIfPresent(UUID.self, forKey: .executingBlockID)
        executionStartedAt = try container.decodeIfPresent(Date.self, forKey: .executionStartedAt)
        timeMagnet = try container.decodeIfPresent(TimeMagnetSettings.self, forKey: .timeMagnet) ?? .disabled
        overtimePromptedBlockIDs = try container.decodeIfPresent([UUID].self, forKey: .overtimePromptedBlockIDs) ?? []
    }
}

class FormulaEngine: ObservableObject {
    
    // MARK: - State
    
    @Published var isRunning: Bool = false
    @Published var blocks: [Block] = []
    @Published var currentBlockIndex: Int = 0
    @Published var elapsedTotal: TimeInterval = 0
    @Published var targetDuration: TimeInterval = 16 * 3600
    @Published var durationCeiling: TimeInterval = 16 * 3600
    @Published var startDate: Date?
    @Published var isCurrentBlockPaused: Bool = false
    @Published var isExecutionModeEnabled: Bool = false
    @Published var executingBlockID: UUID?
    
    private var timer: AnyCancellable?
    private var backgroundObservers = Set<AnyCancellable>()
    private var lastTimelineSyncAt: Date?
    private var accumulatedPausedDuration: TimeInterval = 0
    private var pauseStartedAt: Date?
    private var executionStartedAt: Date?
    private var overtimePromptedBlockIDs: Set<UUID> = []
    
    var formulaId: UUID?
    var formulaName: String = ""
    var timeMagnet: TimeMagnetSettings = .disabled
    
    static let stateKey = "com.cuein.formulaState"

    private var isGlobalTimeMagnetEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: TimeMagnetSetting.storageKey) != nil else {
            return TimeMagnetSetting.defaultValue
        }
        return defaults.bool(forKey: TimeMagnetSetting.storageKey)
    }

    private var expandsDayForOverrun: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: ScheduleOverrunSetting.storageKey) != nil else {
            return ScheduleOverrunSetting.defaultValue
        }
        return defaults.bool(forKey: ScheduleOverrunSetting.storageKey)
    }

    private var isOvertimeCheckInEnabled: Bool {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: OvertimeCheckInSetting.enabledStorageKey) != nil else {
            return OvertimeCheckInSetting.defaultEnabled
        }
        return defaults.bool(forKey: OvertimeCheckInSetting.enabledStorageKey)
    }

    private var overtimeCheckInLimit: TimeInterval {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: OvertimeCheckInSetting.limitStorageKey) != nil else {
            return OvertimeCheckInSetting.defaultLimitSeconds
        }
        return defaults.double(forKey: OvertimeCheckInSetting.limitStorageKey)
    }
    
    init() {
        setupBackgroundObservers()
        restoreState()
    }
    
    // MARK: - Persistence
    
    func saveState() {
        guard isRunning, let startDate = startDate else {
            UserDefaults.standard.removeObject(forKey: Self.stateKey)
            return
        }
        
        let state = PersistedFormulaState(
            formulaId: formulaId,
            formulaName: formulaName,
            blocks: blocks,
            startDate: startDate,
            targetDuration: targetDuration,
            isRunning: true,
            currentBlockIndex: currentBlockIndex,
            elapsedTotal: elapsedTotal,
            accumulatedPausedDuration: accumulatedPausedDuration,
            pauseStartedAt: pauseStartedAt,
            isExecutionModeEnabled: isExecutionModeEnabled,
            executingBlockID: executingBlockID,
            executionStartedAt: executionStartedAt,
            timeMagnet: timeMagnet,
            overtimePromptedBlockIDs: Array(overtimePromptedBlockIDs)
        )
        
        guard let data = try? JSONEncoder().encode(state) else { return }
        UserDefaults.standard.set(data, forKey: Self.stateKey)
    }
    
    func restoreState() {
        guard let data = UserDefaults.standard.data(forKey: Self.stateKey),
              let state = try? JSONDecoder().decode(PersistedFormulaState.self, from: data),
              state.isRunning else { return }
        
        self.formulaId = state.formulaId
        self.formulaName = state.formulaName
        self.blocks = state.blocks
        self.targetDuration = state.targetDuration
        self.durationCeiling = max(state.targetDuration, state.blocks.reduce(0.0) { $0 + $1.duration })
        self.startDate = state.startDate
        self.currentBlockIndex = state.currentBlockIndex
        self.elapsedTotal = state.elapsedTotal
        self.accumulatedPausedDuration = state.accumulatedPausedDuration
        self.pauseStartedAt = state.pauseStartedAt
        self.isCurrentBlockPaused = state.pauseStartedAt != nil
        self.isExecutionModeEnabled = state.isExecutionModeEnabled
        self.executingBlockID = state.executingBlockID
        self.executionStartedAt = state.executionStartedAt
        self.timeMagnet = state.timeMagnet
        self.overtimePromptedBlockIDs = Set(state.overtimePromptedBlockIDs)
        self.lastTimelineSyncAt = state.startDate.addingTimeInterval(max(0, state.elapsedTotal))
        self.isRunning = true

        if executingBlock == nil {
            clearExecutionState()
        }

        synchronizeTimeline(to: Date())
        startTimer()
        resyncNotificationsForCurrentState()
    }
    
    /// Recalculate block positions from wall-clock time, while excluding paused time from block progress.
    private func recalculatePosition(activeElapsed: TimeInterval, wallClockElapsed: TimeInterval) {
        guard !blocks.isEmpty else {
            self.elapsedTotal = max(0, wallClockElapsed)
            self.currentBlockIndex = 0
            return
        }

        var accumulated: TimeInterval = 0
        self.elapsedTotal = max(0, wallClockElapsed)

        for index in blocks.indices where !blocks[index].isChecked {
            blocks[index].elapsedTime = 0
        }
        
        for i in 0..<blocks.count {
            if blocks[i].isChecked {
                accumulated += blocks[i].elapsedTime
                continue
            }
            
            let blockStart = accumulated
            let blockEnd = accumulated + blocks[i].duration
            
            if activeElapsed >= blockEnd && blocks[i].flowLogic == .flowing {
                blocks[i].elapsedTime = blocks[i].duration
                accumulated = blockEnd
            } else if activeElapsed > blockStart {
                let blockElapsed = activeElapsed - blockStart
                blocks[i].elapsedTime = blockElapsed
                self.currentBlockIndex = i
                return
            } else {
                self.currentBlockIndex = i
                return
            }
        }
        
        self.currentBlockIndex = blocks.count - 1
    }
    
    // MARK: - Background Support
    
    private func setupBackgroundObservers() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.handleEnterBackground() }
            .store(in: &backgroundObservers)

        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in self?.handleEnterBackground() }
            .store(in: &backgroundObservers)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.handleReturnToForeground() }
            .store(in: &backgroundObservers)

        NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)
            .sink { [weak self] _ in self?.handleEnterBackground() }
            .store(in: &backgroundObservers)
    }
    
    private func handleEnterBackground() {
        guard isRunning else { return }
        synchronizeTimeline(to: Date())
        saveState()
        stopTimer()
    }
    
    private func handleReturnToForeground() {
        guard isRunning else { return }
        synchronizeTimeline(to: Date())
        startTimer()
        resyncNotificationsForCurrentState()
    }
    
    // MARK: - Computed
    
    var currentBlock: Block? {
        guard currentBlockIndex >= 0, currentBlockIndex < blocks.count else { return nil }
        return blocks[currentBlockIndex]
    }

    var executingBlock: Block? {
        guard let executingBlockID else { return nil }
        return blocks.first(where: { $0.id == executingBlockID })
    }

    var executingBlockIndex: Int? {
        guard let executingBlockID else { return nil }
        return blocks.firstIndex(where: { $0.id == executingBlockID })
    }
    
    var dayProgress: Double {
        guard targetDuration > 0 else { return 0 }
        return min(1, elapsedTotal / targetDuration)
    }

    var remainingDayProgress: Double {
        max(0, 1 - dayProgress)
    }
    
    var totalChecked: Int {
        blocks.filter(\.isChecked).count
    }

    var completedPlannedDayProgress: Double {
        guard targetDuration > 0 else { return 0 }
        let completedDuration = blocks.reduce(0.0) { partialResult, block in
            partialResult + (block.isChecked ? block.duration : 0)
        }
        return min(1, completedDuration / targetDuration)
    }

    var remainingDayTime: TimeInterval {
        max(0, targetDuration - elapsedTotal)
    }
    
    var formattedElapsed: String {
        formatDuration(elapsedTotal)
    }

    var formattedRemaining: String {
        formatDuration(remainingDayTime)
    }

    var dayProgressPercentageLabel: String {
        "\(Int((dayProgress * 100).rounded()))%"
    }

    var remainingDayPercentageLabel: String {
        "\(Int((remainingDayProgress * 100).rounded()))%"
    }

    var completedPlannedDayPercentageLabel: String {
        "\(Int((completedPlannedDayProgress * 100).rounded()))%"
    }
    
    /// Estimated end time
    var estimatedEndTime: Date? {
        guard let start = startDate else { return nil }
        return start.addingTimeInterval(targetDuration)
    }
    
    /// Formatted estimated end time
    var formattedEndTime: String? {
        guard let end = estimatedEndTime else { return nil }
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f.string(from: end)
    }

    var executionElapsed: TimeInterval {
        guard let executionStartedAt else { return 0 }
        return max(0, Date().timeIntervalSince(executionStartedAt))
    }

    var formattedExecutionElapsed: String {
        let totalSeconds = Int(executionElapsed.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
    }
    
    // MARK: - Load Formula
    
    func loadFormula(_ formula: Formula, expandingWith dataStore: DataStore? = nil) {
        self.formulaId = formula.id
        self.formulaName = formula.name
        self.timeMagnet = formula.timeMagnet
        self.targetDuration = formula.targetDuration
        self.durationCeiling = max(formula.targetDuration, formula.blocks.reduce(0.0) { $0 + $1.duration })
        self.currentBlockIndex = 0
        self.elapsedTotal = 0
        self.isRunning = false
        self.startDate = nil
        self.isCurrentBlockPaused = false
        self.isExecutionModeEnabled = false
        self.accumulatedPausedDuration = 0
        self.pauseStartedAt = nil
        self.executingBlockID = nil
        self.executionStartedAt = nil
        self.overtimePromptedBlockIDs.removeAll()
        self.lastTimelineSyncAt = nil
        stopTimer()
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        
        self.blocks = formula.blocks.map {
            resolvedBlock(from: $0, using: dataStore, visitedFormulaIDs: [formula.id])
        }
        
        // Clear any persisted state
        UserDefaults.standard.removeObject(forKey: Self.stateKey)
    }
    
    // MARK: - Start / Stop
    
    func start() {
        guard !blocks.isEmpty else { return }
        let now = Date()
        isRunning = true
        startDate = now
        elapsedTotal = 0
        durationCeiling = max(targetDuration, blocks.reduce(0.0) { $0 + $1.duration })
        isCurrentBlockPaused = false
        isExecutionModeEnabled = false
        accumulatedPausedDuration = 0
        pauseStartedAt = nil
        executingBlockID = nil
        executionStartedAt = nil
        overtimePromptedBlockIDs.removeAll()
        lastTimelineSyncAt = now
        applyTimeMagnetIfNeeded()
        startTimer()
        saveState()
        scheduleNotifications()
    }
    
    func stop() {
        isRunning = false
        isCurrentBlockPaused = false
        isExecutionModeEnabled = false
        accumulatedPausedDuration = 0
        pauseStartedAt = nil
        executingBlockID = nil
        executionStartedAt = nil
        overtimePromptedBlockIDs.removeAll()
        lastTimelineSyncAt = nil
        stopTimer()
        UserDefaults.standard.removeObject(forKey: Self.stateKey)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func clearToday() {
        stopTimer()
        isRunning = false
        blocks = []
        currentBlockIndex = 0
        elapsedTotal = 0
        durationCeiling = 16 * 3600
        startDate = nil
        isCurrentBlockPaused = false
        isExecutionModeEnabled = false
        accumulatedPausedDuration = 0
        pauseStartedAt = nil
        clearExecutionState()
        overtimePromptedBlockIDs.removeAll()
        lastTimelineSyncAt = nil
        formulaId = nil
        formulaName = ""
        timeMagnet = .disabled
        UserDefaults.standard.removeObject(forKey: Self.stateKey)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.tick() }
    }
    
    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }
    
    // MARK: - Timer Tick
    
    private func tick() {
        guard isRunning else { return }
        synchronizeTimeline(to: Date())

        if Int(elapsedTotal) % 30 == 0 {
            saveState()
        }
    }
    
    // MARK: - Check Off

    func setExecutionModeEnabled(_ isEnabled: Bool) {
        guard isExecutionModeEnabled != isEnabled else { return }

        objectWillChange.send()
        isExecutionModeEnabled = isEnabled

        if !isEnabled {
            clearExecutionState()
        } else {
            ensureCurrentBlockIndexValid()
            rebalanceRemainingScheduleIfNeeded()
        }

        persistScheduleChanges()
    }

    func toggleExecutionMode() {
        setExecutionModeEnabled(!isExecutionModeEnabled)
    }

    private func startRunForExecutionIfNeeded() {
        guard !isRunning else { return }
        guard !blocks.isEmpty else { return }

        let now = Date()
        isRunning = true
        startDate = now
        elapsedTotal = 0
        isCurrentBlockPaused = false
        accumulatedPausedDuration = 0
        pauseStartedAt = nil
        clearExecutionState()
        overtimePromptedBlockIDs.removeAll()
        lastTimelineSyncAt = now
        applyTimeMagnetIfNeeded()
        startTimer()
    }

    func playBlockNow(at index: Int) {
        guard blocks.indices.contains(index) else { return }
        guard !blocks[index].isChecked else { return }

        startRunForExecutionIfNeeded()
        synchronizeTimelineIfRunning()

        if isCurrentBlockPaused {
            absorbScheduleSlip(finalizeCurrentPause())
        }

        objectWillChange.send()

        let targetIndex = firstRemainingBlockIndex()
        let finalIndex: Int

        if index == targetIndex {
            finalIndex = index
        } else {
            finalIndex = moveBlock(from: index, to: targetIndex)
        }

        currentBlockIndex = finalIndex

        if isExecutionModeEnabled && isRunning {
            executingBlockID = blocks[finalIndex].id
            executionStartedAt = Date()
        } else {
            clearExecutionState()
        }

        persistScheduleChanges()
    }

    func startExecutingBlock(at index: Int) {
        guard isExecutionModeEnabled else { return }
        guard index >= 0, index < blocks.count else { return }
        guard index >= currentBlockIndex else { return }
        guard !blocks[index].isChecked else { return }

        startRunForExecutionIfNeeded()
        synchronizeTimelineIfRunning()

        if index == currentBlockIndex && isCurrentBlockPaused {
            absorbScheduleSlip(finalizeCurrentPause())
        }

        objectWillChange.send()

        let targetIndex = max(0, min(currentBlockIndex, blocks.count - 1))
        let finalIndex: Int

        if index == targetIndex {
            finalIndex = index
        } else {
            finalIndex = moveBlock(from: index, to: targetIndex)
            currentBlockIndex = finalIndex
        }

        executingBlockID = blocks[finalIndex].id
        executionStartedAt = Date()
        persistScheduleChanges()
    }

    func stopExecutingBlock() {
        guard executingBlockID != nil else { return }
        synchronizeTimelineIfRunning()
        objectWillChange.send()
        clearExecutionState()
        persistScheduleChanges()
    }

    func completeExecutingBlock() {
        guard let executingBlockID,
              let index = blocks.firstIndex(where: { $0.id == executingBlockID }) else {
            clearExecutionState()
            persistScheduleChanges()
            return
        }

        clearExecutionState()
        checkBlock(at: index)
    }

    func pauseCurrentBlock() {
        guard isRunning,
              blocks.indices.contains(currentBlockIndex),
              !blocks[currentBlockIndex].isChecked,
              !isCurrentBlockPaused else { return }

        let now = Date()
        synchronizeTimeline(to: now)
        objectWillChange.send()
        isCurrentBlockPaused = true
        pauseStartedAt = now
        lastTimelineSyncAt = now
        persistScheduleChanges()
    }

    func resumeCurrentBlock() {
        guard isRunning,
              blocks.indices.contains(currentBlockIndex),
              isCurrentBlockPaused else { return }

        let now = Date()
        synchronizeTimeline(to: now)
        objectWillChange.send()
        let pausedDuration = finalizeCurrentPause(at: now)
        absorbScheduleSlip(pausedDuration)
        lastTimelineSyncAt = now
        persistScheduleChanges()
    }

    func toggleCurrentBlockPause() {
        if isCurrentBlockPaused {
            resumeCurrentBlock()
        } else {
            pauseCurrentBlock()
        }
    }
    
    func checkBlock(at index: Int) {
        guard index >= 0, index < blocks.count else { return }
        synchronizeTimelineIfRunning()
        let checkedBlockID = blocks[index].id
        let wasCurrentBlock = index == currentBlockIndex

        if wasCurrentBlock && isCurrentBlockPaused {
            absorbScheduleSlip(finalizeCurrentPause())
        }

        objectWillChange.send()
        let remaining = blocks[index].remainingTime
        markMiniBlocksChecked(at: index)
        blocks[index].isChecked = true
        if executingBlockID == checkedBlockID {
            clearExecutionState()
        }

        var nextCurrentBlockID: UUID?

        if wasCurrentBlock {
            if remaining > 0 {
                redistributeTime(remaining)
            }
            advanceToNextBlock()
            nextCurrentBlockID = currentBlock?.id
        } else {
            nextCurrentBlockID = currentBlock?.id
        }

        moveCheckedBlockToCompletedSection(blockID: checkedBlockID)

        if let nextCurrentBlockID,
           nextCurrentBlockID != checkedBlockID,
           let updatedIndex = blocks.firstIndex(where: { $0.id == nextCurrentBlockID }) {
            currentBlockIndex = updatedIndex
        } else {
            currentBlockIndex = firstRemainingBlockIndex()
        }

        persistScheduleChanges()
    }

    func uncheckBlock(at index: Int) {
        guard index >= 0, index < blocks.count else { return }
        guard blocks[index].isChecked else { return }

        synchronizeTimelineIfRunning()
        objectWillChange.send()
        blocks[index].isChecked = false
        blocks[index].commitmentRating = nil
        unmarkMiniBlocksChecked(at: index)

        if index <= currentBlockIndex || currentBlockIndex >= blocks.count {
            currentBlockIndex = index
        }

        persistScheduleChanges()
    }

    func toggleBlockCheck(at index: Int) {
        guard index >= 0, index < blocks.count else { return }

        if blocks[index].isChecked {
            uncheckBlock(at: index)
        } else {
            checkBlock(at: index)
        }
    }

    func updateCommitmentRating(_ rating: Int?, forBlockWithID id: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == id }) else { return }
        guard blocks[index].isChecked else { return }

        objectWillChange.send()
        if let rating {
            blocks[index].commitmentRating = min(5, max(1, rating))
        } else {
            blocks[index].commitmentRating = nil
        }
        persistScheduleChanges()
    }

    func checkMiniBlock(at blockIndex: Int, miniTaskIndex: Int) {
        guard blockIndex >= 0, blockIndex < blocks.count else { return }
        guard var miniBlocks = blocks[blockIndex].miniBlocks,
              miniTaskIndex >= 0,
              miniTaskIndex < miniBlocks.count else { return }
        guard !miniBlocks[miniTaskIndex].isChecked else { return }

        synchronizeTimelineIfRunning()
        objectWillChange.send()
        miniBlocks[miniTaskIndex].isChecked = true
        blocks[blockIndex].miniBlocks = miniBlocks

        if miniBlocks.allSatisfy(\.isChecked) && !blocks[blockIndex].isChecked {
            checkBlock(at: blockIndex)
        } else {
            persistScheduleChanges()
        }
    }
    
    // MARK: - Advance
    
    private func advanceToNextBlock() {
        var next = currentBlockIndex + 1
        while next < blocks.count && blocks[next].isChecked {
            next += 1
        }
        
        if next < blocks.count {
            currentBlockIndex = next
        }
        // NOTE: formula never auto-stops — user must click stop
    }
    
    // MARK: - Redistribute Time (early check-off)
    
    private func redistributeTime(_ surplus: TimeInterval) {
        let remaining = blocks.enumerated()
            .filter { $0.offset > currentBlockIndex && !$0.element.isChecked && !$0.element.isTimeframeFixed }
            .sorted { $0.element.priority > $1.element.priority }
        
        guard !remaining.isEmpty else { return }
        
        let totalWeight = remaining.reduce(0.0) { $0 + Double($1.element.priority.rawValue) }
        for item in remaining {
            let share = surplus * (Double(item.element.priority.rawValue) / totalWeight)
            blocks[item.offset].duration += share
        }
    }
    
    // MARK: - Insert Tasks

    func moveBlocksAndRestartFlow(fromOffsets offsets: IndexSet, toOffset destination: Int) {
        guard !offsets.isEmpty else { return }
        synchronizeTimelineIfRunning()

        objectWillChange.send()

        let movingBlocks = offsets.map { blocks[$0] }
        for offset in offsets.sorted(by: >) {
            blocks.remove(at: offset)
        }

        let removalCountBeforeDestination = offsets.filter { $0 < destination }.count
        let adjustedDestination = max(0, min(destination - removalCountBeforeDestination, blocks.count))
        blocks.insert(contentsOf: movingBlocks, at: adjustedDestination)

        restartFlowFromCurrentOrder()
        persistScheduleChanges()
    }
    
    func insertTask(_ task: Block, at position: Int? = nil) {
        synchronizeTimelineIfRunning()
        let insertIndex = position ?? (currentBlockIndex + 1)
        let clampedIndex = min(insertIndex, blocks.count)
        blocks.insert(task, at: clampedIndex)
        shrinkToFit()
        persistScheduleChanges()
    }
    
    /// Insert "now" — pause the current block, run the task immediately,
    /// then resume the interrupted block once the inserted task completes.
    func insertTaskNow(_ task: Block) {
        var task = task
        task.flowLogic = .blocking
        synchronizeTimelineIfRunning()

        if isCurrentBlockPaused, blocks.indices.contains(currentBlockIndex) {
            absorbScheduleSlip(finalizeCurrentPause())
        }

        objectWillChange.send()
        clearExecutionState()

        guard !blocks.isEmpty else {
            blocks = [task]
            currentBlockIndex = 0
            persistScheduleChanges()
            return
        }

        guard blocks.indices.contains(currentBlockIndex) else {
            let insertIndex = min(max(currentBlockIndex, 0), blocks.count)
            blocks.insert(task, at: insertIndex)
            currentBlockIndex = insertIndex
            shrinkToFit()
            persistScheduleChanges()
            return
        }

        let interruptedBlock = blocks.remove(at: currentBlockIndex)
        blocks.insert(task, at: currentBlockIndex)
        blocks.insert(interruptedBlock, at: currentBlockIndex + 1)

        // Keep the paused block intact so it can resume from the same point.
        shrinkToFit(protectedBlockIDs: [interruptedBlock.id])
        persistScheduleChanges()
    }

    func recoverForgottenProgress(followRatio: Double, continueRunning: Bool) {
        guard isRunning, !blocks.isEmpty else { return }

        synchronizeTimelineIfRunning()

        let clampedRatio = min(max(followRatio, 0), 1)
        let firstUnchecked = firstRemainingBlockIndex()
        guard blocks.indices.contains(firstUnchecked) else { return }

        objectWillChange.send()

        let currentUncheckedIndex: Int
        if blocks.indices.contains(currentBlockIndex), !blocks[currentBlockIndex].isChecked {
            currentUncheckedIndex = currentBlockIndex
        } else {
            currentUncheckedIndex = firstUnchecked
        }

        var traversedUncreditedTime: TimeInterval = 0
        if firstUnchecked < currentUncheckedIndex {
            traversedUncreditedTime += blocks[firstUnchecked..<currentUncheckedIndex]
                .filter { !$0.isChecked }
                .reduce(0) { $0 + max($1.duration, $1.elapsedTime) }
        }

        if blocks.indices.contains(currentUncheckedIndex), !blocks[currentUncheckedIndex].isChecked {
            traversedUncreditedTime += max(0, blocks[currentUncheckedIndex].elapsedTime)
        }

        var remainingFollowedTime = traversedUncreditedTime * clampedRatio

        for index in firstUnchecked..<blocks.count where !blocks[index].isChecked {
            blocks[index].elapsedTime = 0
            blocks[index].commitmentRating = nil
            if let miniBlocks = blocks[index].miniBlocks, !miniBlocks.isEmpty {
                blocks[index].miniBlocks = miniBlocks.map { miniBlock in
                    var resetMiniBlock = miniBlock
                    resetMiniBlock.isChecked = false
                    return resetMiniBlock
                }
            }
        }

        for index in firstUnchecked..<blocks.count where !blocks[index].isChecked {
            guard remainingFollowedTime > 0 else { break }

            if remainingFollowedTime >= blocks[index].duration {
                blocks[index].elapsedTime = blocks[index].duration
                blocks[index].isChecked = true
                if let miniBlocks = blocks[index].miniBlocks, !miniBlocks.isEmpty {
                    blocks[index].miniBlocks = miniBlocks.map { miniBlock in
                        var checkedMiniBlock = miniBlock
                        checkedMiniBlock.isChecked = true
                        return checkedMiniBlock
                    }
                }
                remainingFollowedTime -= blocks[index].duration
            } else {
                blocks[index].elapsedTime = remainingFollowedTime
                remainingFollowedTime = 0
            }
        }

        let completedBlocks = blocks.filter(\.isChecked)
        let remainingBlocks = blocks.filter { !$0.isChecked }
        blocks = completedBlocks + remainingBlocks

        if remainingBlocks.isEmpty {
            currentBlockIndex = max(0, blocks.count - 1)
            isCurrentBlockPaused = false
            pauseStartedAt = nil
            clearExecutionState()
            persistScheduleChanges()
            return
        }

        currentBlockIndex = completedBlocks.count
        clearExecutionState()

        if continueRunning {
            isCurrentBlockPaused = false
            pauseStartedAt = nil
            rebalanceRemainingScheduleIfNeeded()
        } else {
            isCurrentBlockPaused = true
            pauseStartedAt = Date()
        }

        lastTimelineSyncAt = Date()
        persistScheduleChanges()
    }

    func recalibrateBeforeStart(toTargetDuration duration: TimeInterval) {
        guard !isRunning else { return }

        objectWillChange.send()
        let clampedDuration = min(max(30 * 60, duration), durationCeiling)
        targetDuration = clampedDuration
        scaleBlocksToTargetDuration()
    }

    func setPreStartDuration(_ duration: TimeInterval) {
        guard !isRunning else { return }
        targetDuration = min(max(30 * 60, duration), durationCeiling)
    }

    func extendDayIfNeededForExplicitScheduleEdit() {
        synchronizeTimelineIfRunning()
        let totalScheduled = blocks.reduce(0.0) { $0 + $1.duration }
        let nextCeiling = max(durationCeiling, totalScheduled)
        let nextTarget = max(targetDuration, totalScheduled)

        let durationChanged = nextCeiling != durationCeiling || nextTarget != targetDuration
        durationCeiling = nextCeiling
        targetDuration = nextTarget

        if durationChanged {
            persistScheduleChanges()
        } else {
            syncRuntimeArtifacts()
        }
    }
    
    private func shrinkToFit(protectedBlockIDs: Set<UUID> = []) {
        let totalScheduled = blocks.reduce(0.0) { $0 + $1.duration }
        let overshoot = totalScheduled - targetDuration
        guard overshoot > 0 else { return }

        compactFutureBlocks(by: overshoot, protectedBlockIDs: protectedBlockIDs)
    }

    private func scaleBlocksToTargetDuration() {
        let totalScheduled = blocks.reduce(0.0) { $0 + $1.duration }
        guard totalScheduled > 0 else { return }

        let scale = targetDuration / totalScheduled
        guard scale.isFinite, scale > 0 else { return }

        for index in blocks.indices {
            if blocks[index].isTimeframeFixed { continue }
            blocks[index].duration = max(blocks[index].elapsedTime, blocks[index].duration * scale)
        }
    }

    private func compactFutureBlocks(by deficit: TimeInterval, protectedBlockIDs: Set<UUID> = []) {
        guard deficit > 0 else { return }
        let combinedProtectedIDs = protectedBlockIDs.union(protectedAutoDurationBlockIDs())

        let shrinkable = blocks.enumerated()
            .filter {
                $0.offset > currentBlockIndex &&
                !$0.element.isChecked &&
                !combinedProtectedIDs.contains($0.element.id)
            }
            .sorted { $0.element.priority < $1.element.priority }
        
        var remaining = deficit
        for item in shrinkable {
            guard remaining > 0 else { break }
            let minimumDuration = max(blocks[item.offset].elapsedTime, blocks[item.offset].duration * 0.5)
            let maxShrink = max(0, blocks[item.offset].duration - minimumDuration)
            let shrinkAmount = min(remaining, maxShrink)
            blocks[item.offset].duration -= shrinkAmount
            remaining -= shrinkAmount
        }
    }

    private func rebalanceRemainingScheduleIfNeeded() {
        guard currentBlockIndex < blocks.count else { return }

        let remainingDayTime = max(0, targetDuration - elapsedTotal)
        let startIndex = executionStartIndexForRebalancing()
        let remainingScheduled = blocks.enumerated().reduce(0.0) { partialResult, item in
            let (index, block) = item
            guard index >= startIndex, !block.isChecked else { return partialResult }

            if index == currentBlockIndex {
                return partialResult + max(0, block.remainingTime)
            }

            return partialResult + block.duration
        }

        let deficit = remainingScheduled - remainingDayTime
        guard deficit > 0 else { return }

        if expandsDayForOverrun {
            targetDuration += deficit
        } else {
            compactSchedule(by: deficit, from: startIndex)
        }
    }
    
    // MARK: - Generate Day Log
    
    func generateDayLog(synchronizeIfRunning: Bool = true) -> DayLog {
        if synchronizeIfRunning {
            synchronizeTimelineIfRunning()
        }
        let blockLogs = blocks.map { block in
            BlockLogEntry(
                blockId: block.id,
                blockName: block.name,
                category: block.category,
                subcategory: block.subcategory,
                scheduledDuration: block.duration,
                actualDuration: block.elapsedTime,
                wasChecked: block.isChecked,
                commitmentRating: block.commitmentRating,
                startedAt: startDate,
                completedAt: block.isChecked ? Date() : nil
            )
        }
        
        return DayLog(
            date: startDate ?? Date(),
            formulaId: formulaId,
            formulaName: formulaName,
            blockLogs: blockLogs,
            startedAt: startDate,
            targetDuration: targetDuration
        )
    }
    
    // MARK: - Notifications
    
    func scheduleNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            guard granted else { return }
            self.scheduleBlockNotifications()
        }
    }
    
    private func scheduleBlockNotifications() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        for item in upcomingNotificationItems() {
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: item.interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: item.identifier,
                content: item.content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
    }

    private func resolvedBlock(
        from block: Block,
        using dataStore: DataStore?,
        visitedFormulaIDs: Set<UUID>
    ) -> Block {
        guard let miniFormulaId = block.miniFormulaId,
              let miniFormula = dataStore?.formula(for: miniFormulaId),
              !visitedFormulaIDs.contains(miniFormulaId) else {
            var resolved = block
            resolved.commitmentRating = nil
            resolved.miniBlocks = block.miniBlocks?.map {
                resolvedBlock(from: $0, using: dataStore, visitedFormulaIDs: visitedFormulaIDs)
            }
            return resolved
        }

        var resolved = block
        resolved.commitmentRating = nil
        resolved.miniBlocks = miniFormula.blocks.map {
            resolvedBlock(from: $0, using: dataStore, visitedFormulaIDs: visitedFormulaIDs.union([miniFormulaId]))
        }
        return resolved
    }

    private func markMiniBlocksChecked(at index: Int) {
        guard let miniBlocks = blocks[index].miniBlocks, !miniBlocks.isEmpty else { return }
        blocks[index].miniBlocks = miniBlocks.map { miniBlock in
            var checkedBlock = miniBlock
            checkedBlock.isChecked = true
            return checkedBlock
        }
    }

    private func unmarkMiniBlocksChecked(at index: Int) {
        guard let miniBlocks = blocks[index].miniBlocks, !miniBlocks.isEmpty else { return }
        blocks[index].miniBlocks = miniBlocks.map { miniBlock in
            var uncheckedBlock = miniBlock
            uncheckedBlock.isChecked = false
            return uncheckedBlock
        }
    }

    private func clearExecutionState() {
        executingBlockID = nil
        executionStartedAt = nil
    }

    private func executionStartIndexForRebalancing() -> Int {
        min(max(currentBlockIndex + 1, 0), blocks.count)
    }

    private func compactSchedule(by deficit: TimeInterval, from startIndex: Int, protectedBlockIDs: Set<UUID> = []) {
        guard deficit > 0 else { return }
        let combinedProtectedIDs = protectedBlockIDs.union(protectedAutoDurationBlockIDs())

        let shrinkable = blocks.enumerated()
            .filter {
                $0.offset >= startIndex &&
                !$0.element.isChecked &&
                !combinedProtectedIDs.contains($0.element.id)
            }
            .sorted { $0.element.priority < $1.element.priority }

        var remaining = deficit
        for item in shrinkable {
            guard remaining > 0 else { break }
            let minimumDuration = max(blocks[item.offset].elapsedTime, blocks[item.offset].duration * 0.5)
            let maxShrink = max(0, blocks[item.offset].duration - minimumDuration)
            let shrinkAmount = min(remaining, maxShrink)
            blocks[item.offset].duration -= shrinkAmount
            remaining -= shrinkAmount
        }
    }

    private func firstRemainingBlockIndex() -> Int {
        blocks.firstIndex(where: { !$0.isChecked }) ?? max(0, blocks.count - 1)
    }

    private func moveCheckedBlockToCompletedSection(blockID: UUID) {
        guard let sourceIndex = blocks.firstIndex(where: { $0.id == blockID }) else { return }

        let checkedBlock = blocks.remove(at: sourceIndex)
        let checkedCount = blocks.filter(\.isChecked).count
        blocks.insert(checkedBlock, at: checkedCount)
    }

    private func restartFlowFromCurrentOrder() {
        guard !blocks.isEmpty else {
            currentBlockIndex = 0
            clearExecutionState()
            return
        }

        let previousCurrentBlockID = currentBlock?.id
        let nextCurrentIndex = firstRemainingBlockIndex()

        if let previousCurrentBlockID,
           blocks.indices.contains(nextCurrentIndex),
           previousCurrentBlockID != blocks[nextCurrentIndex].id,
           isCurrentBlockPaused {
            absorbScheduleSlip(finalizeCurrentPause())
        }

        currentBlockIndex = nextCurrentIndex

        guard blocks.indices.contains(currentBlockIndex), !blocks[currentBlockIndex].isChecked else {
            clearExecutionState()
            return
        }

        if isExecutionModeEnabled && isRunning {
            let nextExecutingBlockID = blocks[currentBlockIndex].id
            if executingBlockID != nextExecutingBlockID {
                executingBlockID = nextExecutingBlockID
                executionStartedAt = Date()
            } else if executionStartedAt == nil {
                executionStartedAt = Date()
            }
            return
        }

        clearExecutionState()
    }

    private func ensureCurrentBlockIndexValid() {
        if let nextUnchecked = blocks.firstIndex(where: { !$0.isChecked }) {
            currentBlockIndex = max(currentBlockIndex, nextUnchecked)
            if blocks.indices.contains(currentBlockIndex), blocks[currentBlockIndex].isChecked {
                currentBlockIndex = nextUnchecked
            }
        } else {
            currentBlockIndex = max(0, blocks.count - 1)
        }
    }

    @discardableResult
    private func moveBlock(from fromIndex: Int, to toIndex: Int) -> Int {
        guard fromIndex != toIndex else { return fromIndex }
        guard blocks.indices.contains(fromIndex) else { return fromIndex }

        let block = blocks.remove(at: fromIndex)
        let destination = min(max(toIndex - (fromIndex < toIndex ? 1 : 0), 0), blocks.count)
        blocks.insert(block, at: destination)
        return destination
    }

    private func persistScheduleChanges() {
        applyTimeMagnetIfNeeded()
        saveState()
        resyncNotificationsForCurrentState()
    }

    func syncRuntimeArtifacts() {
        synchronizeTimelineIfRunning()
        ensureCurrentBlockIndexValid()
        persistScheduleChanges()
    }

    private func activeElapsedSinceStart(at date: Date) -> TimeInterval {
        guard let startDate else { return 0 }
        let wallClockElapsed = max(0, date.timeIntervalSince(startDate))
        return max(0, wallClockElapsed - effectivePausedDuration(at: date))
    }

    private func effectivePausedDuration(at date: Date) -> TimeInterval {
        let currentPauseDuration = pauseStartedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0
        return accumulatedPausedDuration + currentPauseDuration
    }

    private func synchronizeTimelineIfRunning() {
        guard isRunning else { return }
        synchronizeTimeline(to: Date())
    }

    private func synchronizeTimeline(to now: Date) {
        guard isRunning, let startDate else { return }

        let previousSyncDate = lastTimelineSyncAt ?? startDate.addingTimeInterval(max(0, elapsedTotal))
        let wallClockDelta = max(0, now.timeIntervalSince(previousSyncDate))
        let wallClockElapsed = max(0, now.timeIntervalSince(startDate))
        elapsedTotal = wallClockElapsed

        if isExecutionModeEnabled {
            synchronizeExecutionMode(by: wallClockDelta)
        } else {
            synchronizeAutomaticMode(by: wallClockDelta)
        }

        lastTimelineSyncAt = now
        triggerOvertimeCheckInIfNeeded(at: now)
    }

    private func synchronizeAutomaticMode(by delta: TimeInterval) {
        guard delta > 0 else { return }
        guard !isCurrentBlockPaused else { return }

        ensureCurrentBlockIndexValid()

        var remainingDelta = delta
        while remainingDelta > 0, blocks.indices.contains(currentBlockIndex) {
            if blocks[currentBlockIndex].isChecked {
                advanceToNextBlock()
                continue
            }

            blocks[currentBlockIndex].elapsedTime += remainingDelta

            guard blocks[currentBlockIndex].flowLogic == .flowing,
                  blocks[currentBlockIndex].elapsedTime >= blocks[currentBlockIndex].duration else {
                remainingDelta = 0
                break
            }

            let overflow = blocks[currentBlockIndex].elapsedTime - blocks[currentBlockIndex].duration
            blocks[currentBlockIndex].elapsedTime = blocks[currentBlockIndex].duration
            let previousIndex = currentBlockIndex
            advanceToNextBlock()

            if currentBlockIndex == previousIndex {
                blocks[currentBlockIndex].elapsedTime += overflow
                break
            }

            remainingDelta = overflow
        }
    }

    private func synchronizeExecutionMode(by delta: TimeInterval) {
        ensureCurrentBlockIndexValid()

        if isCurrentBlockPaused {
            rebalanceRemainingScheduleIfNeeded()
            return
        }

        guard delta > 0 else {
            rebalanceRemainingScheduleIfNeeded()
            return
        }

        if let executingIndex = executingBlockIndex, blocks.indices.contains(executingIndex) {
            currentBlockIndex = executingIndex
            blocks[executingIndex].elapsedTime += delta
        }

        rebalanceRemainingScheduleIfNeeded()
    }

    @discardableResult
    private func finalizeCurrentPause(at date: Date = Date()) -> TimeInterval {
        guard let pauseStartedAt else {
            isCurrentBlockPaused = false
            return 0
        }

        let pausedDuration = max(0, date.timeIntervalSince(pauseStartedAt))
        accumulatedPausedDuration += pausedDuration
        self.pauseStartedAt = nil
        isCurrentBlockPaused = false
        return pausedDuration
    }

    private func triggerOvertimeCheckInIfNeeded(at now: Date) {
        guard isRunning, isOvertimeCheckInEnabled, !isCurrentBlockPaused else { return }

        let activeIndex: Int?
        if isExecutionModeEnabled, let executingIndex = executingBlockIndex {
            activeIndex = executingIndex
        } else if blocks.indices.contains(currentBlockIndex) {
            activeIndex = currentBlockIndex
        } else {
            activeIndex = nil
        }

        guard let activeIndex, blocks.indices.contains(activeIndex) else { return }
        guard !blocks[activeIndex].isChecked else { return }

        let block = blocks[activeIndex]
        let overrun = block.elapsedTime - block.duration
        guard overrun >= overtimeCheckInLimit else { return }
        guard !overtimePromptedBlockIDs.contains(block.id) else { return }

        objectWillChange.send()
        overtimePromptedBlockIDs.insert(block.id)
        isCurrentBlockPaused = true
        pauseStartedAt = now
        lastTimelineSyncAt = now
        persistScheduleChanges()
        sendOvertimeCheckInNotification(for: block)
    }

    private func absorbScheduleSlip(_ slip: TimeInterval, protectedBlockIDs: Set<UUID> = []) {
        guard slip > 0 else { return }

        if expandsDayForOverrun {
            targetDuration += slip
            durationCeiling = max(durationCeiling, targetDuration)
        } else {
            compactFutureBlocks(by: slip, protectedBlockIDs: protectedBlockIDs)
        }
    }

    private func resyncNotificationsForCurrentState() {
        guard isRunning else {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }

        if isCurrentBlockPaused {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
            return
        }

        scheduleBlockNotifications()
    }

    private func sendOvertimeCheckInNotification(for block: Block) {
        let content = UNMutableNotificationContent()
        content.title = block.name
        content.body = "Are you still here?"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "overtime-checkin-\(block.id.uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )

        UNUserNotificationCenter.current().add(request)
    }

    private struct NotificationItem {
        let identifier: String
        let interval: TimeInterval
        let content: UNMutableNotificationContent
    }

    private func upcomingNotificationItems() -> [NotificationItem] {
        guard !blocks.isEmpty else { return [] }

        var items: [NotificationItem] = []
        let now = Date()
        let anchorIndex = notificationAnchorIndex()
        guard blocks.indices.contains(anchorIndex) else {
            return formulaEndNotificationItem(from: now).map { [$0] } ?? []
        }

        var offset = notificationRemainingTimeForAnchor(at: anchorIndex)

        if let currentItem = makeBlockNotificationItem(for: blocks[anchorIndex], interval: offset, isCurrentAnchor: true) {
            items.append(currentItem)
        }

        if blocks[anchorIndex].flowLogic != .blocking {
            for index in blocks.indices where index > anchorIndex && !blocks[index].isChecked {
                offset += blocks[index].duration
                guard let item = makeBlockNotificationItem(for: blocks[index], interval: offset, isCurrentAnchor: false) else { continue }
                items.append(item)

                if blocks[index].flowLogic == .blocking {
                    break
                }
            }
        }

        if let endItem = formulaEndNotificationItem(from: now) {
            items.append(endItem)
        }

        return items
    }

    private func notificationAnchorIndex() -> Int {
        if blocks.indices.contains(currentBlockIndex), !blocks[currentBlockIndex].isChecked {
            return currentBlockIndex
        }

        return blocks.firstIndex(where: { !$0.isChecked }) ?? currentBlockIndex
    }

    private func notificationRemainingTimeForAnchor(at index: Int) -> TimeInterval {
        guard blocks.indices.contains(index) else { return 0 }

        if isExecutionModeEnabled {
            if executingBlockID == nil && index == currentBlockIndex {
                return max(0, blocks[index].remainingTime)
            }

            let consumedBeforeAnchor = scheduledElapsedBeforeIndex(index)
            let elapsedInsideAnchor = max(0, elapsedTotal - consumedBeforeAnchor)
            return max(0, blocks[index].duration - elapsedInsideAnchor)
        }

        return max(0, blocks[index].remainingTime)
    }

    private func scheduledElapsedBeforeIndex(_ index: Int) -> TimeInterval {
        guard index > 0 else { return 0 }

        return blocks[..<index].reduce(0) { partialResult, block in
            partialResult + (block.isChecked ? block.elapsedTime : block.duration)
        }
    }

    private func makeBlockNotificationItem(for block: Block, interval: TimeInterval, isCurrentAnchor: Bool) -> NotificationItem? {
        guard interval > 0 else { return nil }

        let content = UNMutableNotificationContent()
        content.sound = .default

        if block.flowLogic == .blocking {
            content.title = "Block Overdue"
            content.body = "\(block.name) reached its planned end and is still holding the schedule."
        } else if isExecutionModeEnabled {
            content.title = "Schedule Shift"
            content.body = "\(block.name) reached its scheduled end. Review the next block."
        } else {
            content.title = "Block Complete"
            content.body = "\(block.name) is done. Next block starting."
        }

        return NotificationItem(
            identifier: "block-\(block.id.uuidString)",
            interval: interval,
            content: content
        )
    }

    private func formulaEndNotificationItem(from now: Date) -> NotificationItem? {
        guard let startDate else { return nil }

        let endDate = startDate.addingTimeInterval(targetDuration)
        let interval = endDate.timeIntervalSince(now)
        guard interval > 0 else { return nil }

        let content = UNMutableNotificationContent()
        content.title = "Formula Complete"
        content.body = "\(formulaName) is done for today!"
        content.sound = .default

        return NotificationItem(identifier: "formula-end", interval: interval, content: content)
    }

    private func applyTimeMagnetIfNeeded() {
        let hasFixedStarts = blocks.contains { $0.hasFixedStartTime }
        let usesTimeMagnet = isGlobalTimeMagnetEnabled && timeMagnet.isEnabled
        guard (usesTimeMagnet || hasFixedStarts), blocks.count > 1, let startDate else { return }

        let anchorIndex = magnetAnchorIndex()
        guard blocks.indices.contains(anchorIndex), anchorIndex < blocks.count - 1 else { return }

        let originalStartOffsets = scheduledStartOffsets()
        let totalScheduledDuration = blocks.reduce(0.0) { $0 + $1.duration }
        var adjustedStartOffsets = originalStartOffsets
        var previousBoundary = originalStartOffsets[anchorIndex]

        for index in (anchorIndex + 1)..<blocks.count {
            let minAllowed = previousBoundary + minimumMagnetDuration(for: index - 1, anchorIndex: anchorIndex)
            let maxAllowed = totalScheduledDuration - minimumTailDuration(from: index, anchorIndex: anchorIndex)
            guard minAllowed <= maxAllowed else { continue }

            let targetOffset = targetMagnetStartOffset(
                for: blocks[index],
                originalOffset: originalStartOffsets[index],
                startDate: startDate,
                usesTimeMagnet: usesTimeMagnet
            )
            let clampedOffset = min(max(targetOffset, minAllowed), maxAllowed)
            adjustedStartOffsets[index] = clampedOffset
            previousBoundary = clampedOffset
        }

        for index in anchorIndex..<(blocks.count - 1) {
            let nextStart = adjustedStartOffsets[index + 1]
            let currentStart = index == anchorIndex ? originalStartOffsets[index] : adjustedStartOffsets[index]
            blocks[index].duration = max(
                minimumMagnetDuration(for: index, anchorIndex: anchorIndex),
                nextStart - currentStart
            )
        }

        if let lastIndex = blocks.indices.last {
            let lastStart = lastIndex == anchorIndex ? originalStartOffsets[lastIndex] : adjustedStartOffsets[lastIndex]
            blocks[lastIndex].duration = max(
                minimumMagnetDuration(for: lastIndex, anchorIndex: anchorIndex),
                totalScheduledDuration - lastStart
            )
        }
    }

    private func magnetAnchorIndex() -> Int {
        let firstUnchecked = blocks.firstIndex(where: { !$0.isChecked }) ?? currentBlockIndex
        return min(max(firstUnchecked, 0), max(0, blocks.count - 1))
    }

    private func scheduledStartOffsets() -> [TimeInterval] {
        var offsets: [TimeInterval] = []
        var runningOffset: TimeInterval = 0

        for block in blocks {
            offsets.append(runningOffset)
            runningOffset += block.duration
        }

        return offsets
    }

    private func minimumTailDuration(from index: Int, anchorIndex: Int) -> TimeInterval {
        guard index < blocks.count else { return 0 }

        return blocks[index...].enumerated().reduce(0.0) { partialResult, item in
            let actualIndex = index + item.offset
            return partialResult + minimumMagnetDuration(for: actualIndex, anchorIndex: anchorIndex)
        }
    }

    private func minimumMagnetDuration(for index: Int, anchorIndex: Int) -> TimeInterval {
        let baseMinimum: TimeInterval = 5 * 60
        guard blocks.indices.contains(index) else { return baseMinimum }

        if index == anchorIndex && isRunning && !blocks[index].isChecked {
            return max(baseMinimum, blocks[index].elapsedTime + 1)
        }

        return baseMinimum
    }

    private func targetMagnetStartOffset(
        for block: Block,
        originalOffset: TimeInterval,
        startDate: Date,
        usesTimeMagnet: Bool
    ) -> TimeInterval {
        if let fixedStartSecondsFromMidnight = block.fixedStartSecondsFromMidnight {
            return max(0, anchoredDate(for: fixedStartSecondsFromMidnight, relativeTo: startDate).timeIntervalSince(startDate))
        }

        if let scheduledTime = block.scheduledTime {
            return max(0, scheduledTime.timeIntervalSince(startDate))
        }

        guard usesTimeMagnet else { return originalOffset }

        let interval = timeMagnet.interval(for: block.priority)
        guard interval > 0 else { return originalOffset }

        let absoluteTime = startDate.addingTimeInterval(originalOffset).timeIntervalSinceReferenceDate
        let roundedAbsoluteTime = (absoluteTime / interval).rounded() * interval
        return max(0, roundedAbsoluteTime - startDate.timeIntervalSinceReferenceDate)
    }

    private func anchoredDate(for secondsFromMidnight: TimeInterval, relativeTo startDate: Date) -> Date {
        let calendar = Calendar.current
        let normalizedSeconds = max(0, secondsFromMidnight)
        let hour = Int(normalizedSeconds) / 3600
        let minute = (Int(normalizedSeconds) % 3600) / 60

        var components = calendar.dateComponents([.year, .month, .day], from: startDate)
        components.hour = hour
        components.minute = minute
        components.second = 0

        let sameDay = calendar.date(from: components) ?? startDate
        if sameDay >= startDate {
            return sameDay
        }

        return calendar.date(byAdding: .day, value: 1, to: sameDay) ?? sameDay
    }

    private func protectedAutoDurationBlockIDs() -> Set<UUID> {
        Set(blocks.filter(\.isTimeframeFixed).map(\.id))
    }
}
