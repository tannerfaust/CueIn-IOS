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
}

class FormulaEngine: ObservableObject {
    
    // MARK: - State
    
    @Published var isRunning: Bool = false
    @Published var blocks: [Block] = []
    @Published var currentBlockIndex: Int = 0
    @Published var elapsedTotal: TimeInterval = 0
    @Published var targetDuration: TimeInterval = 16 * 3600
    @Published var startDate: Date?
    
    private var timer: AnyCancellable?
    private var backgroundObservers = Set<AnyCancellable>()
    
    var formulaId: UUID?
    var formulaName: String = ""
    
    static let stateKey = "com.cuein.formulaState"
    
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
            currentBlockIndex: currentBlockIndex
        )
        
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.stateKey)
        }
    }
    
    func restoreState() {
        guard let data = UserDefaults.standard.data(forKey: Self.stateKey),
              let state = try? JSONDecoder().decode(PersistedFormulaState.self, from: data),
              state.isRunning else { return }
        
        self.formulaId = state.formulaId
        self.formulaName = state.formulaName
        self.blocks = state.blocks
        self.targetDuration = state.targetDuration
        self.startDate = state.startDate
        self.currentBlockIndex = state.currentBlockIndex
        
        // Calculate where we should be based on real time
        let elapsed = Date().timeIntervalSince(state.startDate)
        recalculatePosition(totalElapsed: elapsed)
        
        self.isRunning = true
        startTimer()
    }
    
    /// Recalculate block positions based on actual elapsed wall-clock time
    private func recalculatePosition(totalElapsed: TimeInterval) {
        var accumulated: TimeInterval = 0
        self.elapsedTotal = 0
        
        for i in 0..<blocks.count {
            if blocks[i].isChecked {
                // Already checked — use its recorded elapsed time
                self.elapsedTotal += blocks[i].elapsedTime
                accumulated += blocks[i].elapsedTime
                continue
            }
            
            let blockStart = accumulated
            let blockEnd = accumulated + blocks[i].duration
            
            if totalElapsed >= blockEnd && blocks[i].flowLogic == .flowing {
                // This flowing block is fully past — mark completed
                blocks[i].elapsedTime = blocks[i].duration
                self.elapsedTotal += blocks[i].duration
                accumulated = blockEnd
            } else if totalElapsed > blockStart {
                // We're in this block
                let blockElapsed = totalElapsed - blockStart
                blocks[i].elapsedTime = blockElapsed
                self.elapsedTotal += blockElapsed
                self.currentBlockIndex = i
                return
            } else {
                // Haven't reached this block yet
                self.currentBlockIndex = i
                return
            }
        }
        
        // All blocks done
        self.elapsedTotal = totalElapsed
        self.currentBlockIndex = blocks.count - 1
    }
    
    // MARK: - Background Support
    
    private func setupBackgroundObservers() {
        NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)
            .sink { [weak self] _ in self?.handleEnterBackground() }
            .store(in: &backgroundObservers)
        
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.handleReturnToForeground() }
            .store(in: &backgroundObservers)
    }
    
    private func handleEnterBackground() {
        guard isRunning else { return }
        saveState()
        stopTimer()
    }
    
    private func handleReturnToForeground() {
        guard isRunning, let sd = startDate else { return }
        let elapsed = Date().timeIntervalSince(sd)
        recalculatePosition(totalElapsed: elapsed)
        startTimer()
    }
    
    // MARK: - Computed
    
    var currentBlock: Block? {
        guard currentBlockIndex >= 0, currentBlockIndex < blocks.count else { return nil }
        return blocks[currentBlockIndex]
    }
    
    var dayProgress: Double {
        guard targetDuration > 0 else { return 0 }
        return min(1, elapsedTotal / targetDuration)
    }
    
    var totalChecked: Int {
        blocks.filter(\.isChecked).count
    }
    
    var formattedElapsed: String {
        let hours = Int(elapsedTotal) / 3600
        let minutes = (Int(elapsedTotal) % 3600) / 60
        return String(format: "%dh %02dm", hours, minutes)
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
    
    // MARK: - Load Formula
    
    func loadFormula(_ formula: Formula, expandingWith dataStore: DataStore? = nil) {
        self.formulaId = formula.id
        self.formulaName = formula.name
        self.targetDuration = formula.targetDuration
        self.currentBlockIndex = 0
        self.elapsedTotal = 0
        self.isRunning = false
        self.startDate = nil
        stopTimer()
        
        // Expand mini-formula blocks
        var expandedBlocks: [Block] = []
        for block in formula.blocks {
            if let miniId = block.miniFormulaId,
               let miniFormula = dataStore?.formula(for: miniId) {
                for subBlock in miniFormula.blocks {
                    let expanded = Block(
                        name: subBlock.name,
                        duration: subBlock.duration,
                        category: subBlock.category,
                        subcategory: subBlock.subcategory,
                        priority: subBlock.priority,
                        flowLogic: subBlock.flowLogic,
                        colorHex: subBlock.colorHex
                    )
                    expandedBlocks.append(expanded)
                }
            } else {
                expandedBlocks.append(block)
            }
        }
        self.blocks = expandedBlocks
        
        // Clear any persisted state
        UserDefaults.standard.removeObject(forKey: Self.stateKey)
    }
    
    // MARK: - Start / Stop
    
    func start() {
        guard !blocks.isEmpty else { return }
        isRunning = true
        startDate = Date()
        startTimer()
        saveState()
        scheduleNotifications()
    }
    
    func stop() {
        isRunning = false
        stopTimer()
        UserDefaults.standard.removeObject(forKey: Self.stateKey)
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }
    
    private func startTimer() {
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
        guard isRunning, currentBlockIndex < blocks.count else { return }
        
        elapsedTotal += 1
        blocks[currentBlockIndex].elapsedTime += 1
        
        let block = blocks[currentBlockIndex]
        
        if block.flowLogic == .flowing && block.elapsedTime >= block.duration && !block.isChecked {
            advanceToNextBlock()
        }
        
        // Save periodically (every 30s)
        if Int(elapsedTotal) % 30 == 0 {
            saveState()
        }
    }
    
    // MARK: - Check Off
    
    func checkBlock(at index: Int) {
        guard index >= 0, index < blocks.count else { return }
        blocks[index].isChecked = true
        
        if index == currentBlockIndex {
            let remaining = blocks[index].remainingTime
            if remaining > 0 {
                redistributeTime(remaining)
            }
            advanceToNextBlock()
        }
        saveState()
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
            .filter { $0.offset > currentBlockIndex && !$0.element.isChecked }
            .sorted { $0.element.priority > $1.element.priority }
        
        guard !remaining.isEmpty else { return }
        
        let totalWeight = remaining.reduce(0.0) { $0 + Double($1.element.priority.rawValue) }
        for item in remaining {
            let share = surplus * (Double(item.element.priority.rawValue) / totalWeight)
            blocks[item.offset].duration += share
        }
    }
    
    // MARK: - Insert Tasks
    
    func insertTask(_ task: Block, at position: Int? = nil) {
        let insertIndex = position ?? (currentBlockIndex + 1)
        let clampedIndex = min(insertIndex, blocks.count)
        blocks.insert(task, at: clampedIndex)
        shrinkToFit()
        saveState()
    }
    
    /// Insert "now" — pause current block and start this one immediately
    func insertTaskNow(_ task: Block) {
        blocks.insert(task, at: currentBlockIndex + 1)
        // Advance to the new task immediately
        currentBlockIndex += 1
        shrinkToFit()
        saveState()
    }
    
    private func shrinkToFit() {
        let totalScheduled = blocks.reduce(0.0) { $0 + $1.duration }
        let overshoot = totalScheduled - targetDuration
        guard overshoot > 0 else { return }
        
        let shrinkable = blocks.enumerated()
            .filter { $0.offset > currentBlockIndex && !$0.element.isChecked }
            .sorted { $0.element.priority < $1.element.priority }
        
        var remaining = overshoot
        for item in shrinkable {
            guard remaining > 0 else { break }
            let maxShrink = blocks[item.offset].duration * 0.5
            let shrinkAmount = min(remaining, maxShrink)
            blocks[item.offset].duration -= shrinkAmount
            remaining -= shrinkAmount
        }
    }
    
    // MARK: - Generate Day Log
    
    func generateDayLog() -> DayLog {
        let blockLogs = blocks.map { block in
            BlockLogEntry(
                blockId: block.id,
                blockName: block.name,
                category: block.category,
                subcategory: block.subcategory,
                scheduledDuration: block.duration,
                actualDuration: block.elapsedTime,
                wasChecked: block.isChecked,
                startedAt: startDate,
                completedAt: block.isChecked ? Date() : nil
            )
        }
        
        return DayLog(
            date: Date(),
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
        
        guard let start = startDate else { return }
        var offset: TimeInterval = 0
        
        for block in blocks where !block.isChecked {
            offset += block.duration
            
            let triggerDate = start.addingTimeInterval(offset)
            guard triggerDate > Date() else { continue }
            
            let content = UNMutableNotificationContent()
            content.title = "Block Complete"
            content.body = "\(block.name) is done. Next block starting."
            content.sound = .default
            
            let interval = triggerDate.timeIntervalSinceNow
            guard interval > 0 else { continue }
            
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(
                identifier: "block-\(block.id.uuidString)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request)
        }
        
        // End of formula notification
        let endContent = UNMutableNotificationContent()
        endContent.title = "Formula Complete"
        endContent.body = "\(formulaName) is done for today!"
        endContent.sound = .default
        
        let endDate = start.addingTimeInterval(targetDuration)
        let endInterval = endDate.timeIntervalSinceNow
        if endInterval > 0 {
            let endTrigger = UNTimeIntervalNotificationTrigger(timeInterval: endInterval, repeats: false)
            let endRequest = UNNotificationRequest(identifier: "formula-end", content: endContent, trigger: endTrigger)
            UNUserNotificationCenter.current().add(endRequest)
        }
    }
}
