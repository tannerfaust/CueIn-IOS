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
    
    @Published var engine: FormulaEngine
    @Published var isStarted: Bool = false
    @Published var showRoadblockSheet: Bool = false
    @Published var showAddTaskSheet: Bool = false
    @Published var showChangeFormula: Bool = false
    @Published var showNewFormula: Bool = false
    @Published var viewMode: ViewMode = .regular
    @Published var formulaName: String = ""
    @Published var stageName: String = ""
    @Published var showRealTime: Bool = false
    
    var dataStore: DataStore
    private var cancellables = Set<AnyCancellable>()
    
    enum ViewMode: String, CaseIterable {
        case focused = "Focused"
        case regular = "Regular"
    }
    
    init(dataStore: DataStore, engine: FormulaEngine) {
        self.dataStore = dataStore
        self.engine = engine
        self.stageName = dataStore.profile.stageName
        
        // Check if engine already restored from UserDefaults
        if engine.isRunning {
            self.isStarted = true
            self.formulaName = engine.formulaName
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
        if let formula = dataStore.todayFormula() {
            engine.loadFormula(formula, expandingWith: dataStore)
            formulaName = formula.name
        }
    }
    
    func startDay() {
        engine.start()
    }
    
    func stopDay() {
        // Save day log to monitoring before stopping
        let log = engine.generateDayLog()
        dataStore.addDayLog(log)
        engine.stop()
    }
    
    func checkBlock(at index: Int) {
        engine.checkBlock(at: index)
    }
    
    func removeBlock(at index: Int) {
        guard index >= 0, index < engine.blocks.count else { return }
        engine.blocks.remove(at: index)
        engine.saveState()
    }
    
    func triggerRoadblock() {
        showRoadblockSheet = true
    }
    
    func addTask(name: String, duration: TimeInterval, flowLogic: FlowLogic, category: BlockCategory, scheduledTime: Date? = nil) {
        var task = Block(
            name: name,
            duration: duration,
            category: category,
            priority: .medium,
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
    
    /// Add task that overrides current block immediately
    func addTaskNow(name: String, duration: TimeInterval, flowLogic: FlowLogic, category: BlockCategory) {
        let task = Block(
            name: name,
            duration: duration,
            category: category,
            priority: .high,
            flowLogic: flowLogic
        )
        engine.insertTaskNow(task)
        showRoadblockSheet = false
    }
    
    // MARK: - Duration Control (before start)
    
    func changeDuration(_ hours: Double) {
        engine.targetDuration = hours * 3600
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
        guard let startDate = engine.startDate, showRealTime else { return nil }
        
        var offset: TimeInterval = 0
        for i in 0..<index {
            offset += engine.blocks[i].duration
        }
        
        let blockTime = startDate.addingTimeInterval(offset)
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: blockTime)
    }
    
    func tuneIntoFlow() {
        if let miniFormula = dataStore.formulas.first(where: { $0.type == .mini }) {
            let flowBlock = Block(
                name: "🌊 " + miniFormula.name,
                duration: miniFormula.blocks.reduce(0) { $0 + $1.duration },
                category: .wellness,
                priority: .medium,
                flowLogic: .blocking
            )
            engine.insertTask(flowBlock)
            
            for (i, block) in miniFormula.blocks.enumerated() {
                let subBlock = Block(
                    name: block.name,
                    duration: block.duration,
                    category: block.category,
                    subcategory: block.subcategory,
                    priority: block.priority,
                    flowLogic: block.flowLogic,
                    colorHex: block.colorHex
                )
                engine.insertTask(subBlock, at: engine.currentBlockIndex + 2 + i)
            }
        }
        showRoadblockSheet = false
    }
}
