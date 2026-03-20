//
//  DataStore.swift
//  CueIn
//
//  Central data store — single source of truth for all app data.
//  Seed data only runs once (first launch). Resets persist via UserDefaults.
//

import Foundation
import Combine

class DataStore: ObservableObject {
    
    // MARK: - Published Data
    
    @Published var formulas: [Formula] = []
    @Published var weekSchedule: WeekSchedule = WeekSchedule()
    @Published var profile: UserProfile = UserProfile()
    @Published var qsEntries: [QSEntry] = []
    @Published var qsRecords: [QSRecord] = []
    @Published var dayLogs: [DayLog] = []
    
    /// User-created subcategories (persisted per category)
    @Published var customSubcategories: [BlockCategory: [String]] = [:]
    
    private static let hasSeededKey = "com.cuein.hasSeeded"
    private static let hasResetAllKey = "com.cuein.hasResetAll"
    
    // MARK: - Init
    
    init() {
        let hasResetAll = UserDefaults.standard.bool(forKey: Self.hasResetAllKey)
        let hasSeeded = UserDefaults.standard.bool(forKey: Self.hasSeededKey)
        
        if !hasSeeded && !hasResetAll {
            seedSampleData()
            UserDefaults.standard.set(true, forKey: Self.hasSeededKey)
        }
    }
    
    // MARK: - Formula CRUD
    
    func addFormula(_ formula: Formula) {
        formulas.append(formula)
    }
    
    func updateFormula(_ formula: Formula) {
        if let index = formulas.firstIndex(where: { $0.id == formula.id }) {
            formulas[index] = formula
        }
    }
    
    func deleteFormula(_ id: UUID) {
        formulas.removeAll { $0.id == id }
    }
    
    func formula(for id: UUID) -> Formula? {
        formulas.first { $0.id == id }
    }
    
    /// Get today's formula based on the week schedule
    func todayFormula() -> Formula? {
        let today = DayOfWeek.today
        guard let formulaId = weekSchedule.formulaIds(for: today).first else { return nil }
        return formula(for: formulaId)
    }
    
    // MARK: - Day Log
    
    func addDayLog(_ log: DayLog) {
        // Replace existing log for the same date
        let calendar = Calendar.current
        dayLogs.removeAll { calendar.isDate($0.date, inSameDayAs: log.date) }
        dayLogs.append(log)
    }
    
    func dayLog(for date: Date) -> DayLog? {
        let calendar = Calendar.current
        return dayLogs.first { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    /// Last N day logs, sorted newest first
    func recentLogs(_ count: Int) -> [DayLog] {
        Array(dayLogs.sorted { $0.date > $1.date }.prefix(count))
    }
    
    // MARK: - QS
    
    func addQSEntry(_ entry: QSEntry) {
        qsEntries.append(entry)
    }
    
    func addQSRecord(_ record: QSRecord) {
        qsRecords.append(record)
    }
    
    // MARK: - Subcategory Management
    
    func subcategories(for category: BlockCategory) -> [String] {
        let defaults = category.defaultSubcategories
        let custom = customSubcategories[category] ?? []
        return Array(Set(defaults + custom)).sorted()
    }
    
    func addSubcategory(_ name: String, to category: BlockCategory) {
        var list = customSubcategories[category] ?? []
        if !list.contains(name) {
            list.append(name)
            customSubcategories[category] = list
        }
    }
    
    // MARK: - Reset & Data Management
    
    /// Reset history only — keeps formulas, schedule, goals
    func resetHistory() {
        dayLogs.removeAll()
        qsRecords.removeAll()
    }
    
    /// Full reset — everything back to empty. Prevents re-seeding.
    func resetAll() {
        formulas.removeAll()
        weekSchedule = WeekSchedule()
        profile = UserProfile()
        qsEntries.removeAll()
        qsRecords.removeAll()
        dayLogs.removeAll()
        customSubcategories.removeAll()
        
        // Prevent seed data from coming back
        UserDefaults.standard.set(true, forKey: Self.hasResetAllKey)
        UserDefaults.standard.removeObject(forKey: FormulaEngine.stateKey)
    }
    
    /// Auto-delete metrics older than `days` — preserves goals
    func autoDeleteOldMetrics(olderThan days: Int = 30) {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: Date()) else { return }
        dayLogs.removeAll { $0.date < cutoff }
        qsRecords.removeAll { $0.date < cutoff }
    }
    
    // MARK: - Seed Sample Data
    
    private func seedSampleData() {
        profile = UserProfile(
            stageName: "Building My System",
            goals: [
                Goal(title: "Master Deep Work", description: "Sustain 4+ hours of deep focus daily", category: .work),
                Goal(title: "Run a Marathon", description: "Build cardio endurance over 6 months", category: .sport),
                Goal(title: "Learn SwiftUI", description: "Complete iOS development course", category: .study)
            ],
            dailyTargetHours: 16
        )
        
        let morningRoutine = Formula(
            name: "Morning Routine",
            targetDuration: 45 * 60,
            blocks: [
                Block(name: "Morning Run", duration: 15 * 60, category: .sport, subcategory: "Cardio", priority: .medium, flowLogic: .flowing, colorHex: "34D399"),
                Block(name: "Cold Shower", duration: 5 * 60, category: .wellness, subcategory: "Cold Shower", priority: .low, flowLogic: .flowing, colorHex: "F472B6"),
                Block(name: "Meditation", duration: 10 * 60, category: .wellness, subcategory: "Meditation", priority: .medium, flowLogic: .flowing, colorHex: "F472B6"),
                Block(name: "Breakfast", duration: 15 * 60, category: .wellness, priority: .low, flowLogic: .flowing, colorHex: "FBBF24")
            ],
            type: .mini,
            emoji: "🌅"
        )
        
        let productiveWeekday = Formula(
            name: "Productive Weekday",
            targetDuration: 16 * 3600,
            blocks: [
                Block(name: "Morning Routine", duration: 45 * 60, category: .wellness, priority: .high, flowLogic: .blocking, colorHex: "F472B6", miniFormulaId: morningRoutine.id),
                Block(name: "Deep Work", duration: 2 * 3600, category: .work, subcategory: "Deep Work", priority: .high, flowLogic: .blocking, colorHex: "6C63FF"),
                Block(name: "Study Session", duration: 90 * 60, category: .study, subcategory: "Computer Science", priority: .high, flowLogic: .blocking, colorHex: "60A5FA"),
                Block(name: "Lunch Break", duration: 30 * 60, category: .wellness, priority: .low, flowLogic: .flowing, colorHex: "FBBF24"),
                Block(name: "Creative Work", duration: 90 * 60, category: .work, subcategory: "Creative Work", priority: .medium, flowLogic: .flowing, colorHex: "A78BFA"),
                Block(name: "Shallow Work", duration: 60 * 60, category: .work, subcategory: "Shallow Work", priority: .low, flowLogic: .flowing, colorHex: "9CA3AF"),
                Block(name: "Training", duration: 60 * 60, category: .sport, subcategory: "Resistance Training", priority: .medium, flowLogic: .blocking, colorHex: "34D399"),
                Block(name: "Reading", duration: 45 * 60, category: .study, subcategory: "Languages", priority: .low, flowLogic: .flowing, colorHex: "60A5FA"),
                Block(name: "Evening Wind-down", duration: 30 * 60, category: .wellness, subcategory: "Journaling", priority: .low, flowLogic: .flowing, colorHex: "F472B6")
            ],
            type: .full,
            emoji: "⚡"
        )
        
        let recoveryDay = Formula(
            name: "Recovery Day",
            targetDuration: 14 * 3600,
            blocks: [
                Block(name: "Sleep In", duration: 60 * 60, category: .wellness, priority: .medium, flowLogic: .flowing, colorHex: "F472B6"),
                Block(name: "Light Stretch", duration: 30 * 60, category: .sport, subcategory: "Stretching", priority: .low, flowLogic: .flowing, colorHex: "34D399"),
                Block(name: "Brunch", duration: 45 * 60, category: .wellness, priority: .low, flowLogic: .flowing, colorHex: "FBBF24"),
                Block(name: "Creative Projects", duration: 2 * 3600, category: .work, subcategory: "Creative Work", priority: .medium, flowLogic: .flowing, colorHex: "A78BFA"),
                Block(name: "Free Time", duration: 3 * 3600, category: .custom, priority: .low, flowLogic: .flowing, colorHex: "FBBF24"),
                Block(name: "Light Reading", duration: 60 * 60, category: .study, priority: .low, flowLogic: .flowing, colorHex: "60A5FA")
            ],
            type: .full,
            emoji: "🌿"
        )
        
        formulas = [morningRoutine, productiveWeekday, recoveryDay]
        
        weekSchedule = WeekSchedule(name: "Standard Week")
        weekSchedule.setFormulaIds([productiveWeekday.id], for: .monday)
        weekSchedule.setFormulaIds([productiveWeekday.id], for: .tuesday)
        weekSchedule.setFormulaIds([productiveWeekday.id], for: .wednesday)
        weekSchedule.setFormulaIds([productiveWeekday.id], for: .thursday)
        weekSchedule.setFormulaIds([productiveWeekday.id], for: .friday)
        weekSchedule.setFormulaIds([recoveryDay.id], for: .saturday)
        weekSchedule.setFormulaIds([recoveryDay.id], for: .sunday)
        
        qsEntries = [
            QSEntry(name: "Wake-up Time", inputType: .time, trigger: .onFirstLog, automation: .automatic, icon: "sunrise"),
            QSEntry(name: "Sleep Duration", inputType: .number, trigger: .onFirstLog, automation: .proactive, icon: "moon.zzz"),
            QSEntry(name: "Mood", inputType: .options, trigger: .scheduled, automation: .proactive, options: ["😊 Great", "🙂 Good", "😐 Okay", "😟 Low", "😞 Bad"], icon: "face.smiling"),
            QSEntry(name: "Junk Food", inputType: .boolean, trigger: .none, automation: .proactive, defaultTrue: true, icon: "fork.knife"),
            QSEntry(name: "Exercise Done", inputType: .boolean, trigger: .none, automation: .proactive, icon: "figure.walk"),
            QSEntry(name: "Daily Note", inputType: .text, trigger: .none, automation: .proactive, icon: "note.text")
        ]
        
        seedSampleDayLogs(formulaId: productiveWeekday.id, formulaName: productiveWeekday.name)
    }
    
    private func seedSampleDayLogs(formulaId: UUID, formulaName: String) {
        let calendar = Calendar.current
        for daysAgo in 1...7 {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }
            let adherence = Double.random(in: 0.5...1.0)
            let totalBlocks = Int.random(in: 6...9)
            let checkedBlocks = Int(Double(totalBlocks) * adherence)
            
            var blockLogs: [BlockLogEntry] = []
            let categories: [BlockCategory] = [.work, .work, .study, .sport, .wellness]
            let subcategories = ["Deep Work", "Shallow Work", "Computer Science", "Cardio", "Meditation"]
            
            for i in 0..<totalBlocks {
                let catIndex = i % categories.count
                let sched = TimeInterval.random(in: 1800...7200)
                blockLogs.append(BlockLogEntry(
                    blockId: UUID(),
                    blockName: "Block \(i + 1)",
                    category: categories[catIndex],
                    subcategory: subcategories[catIndex],
                    scheduledDuration: sched,
                    actualDuration: sched * Double.random(in: 0.7...1.1),
                    wasChecked: i < checkedBlocks
                ))
            }
            
            dayLogs.append(DayLog(
                date: date,
                formulaId: formulaId,
                formulaName: formulaName,
                blockLogs: blockLogs,
                targetDuration: 16 * 3600
            ))
        }
    }
}
