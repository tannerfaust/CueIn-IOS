//
//  MonitorViewModel.swift
//  CueIn
//
//  State management for Monitor tab — Stats + QS.
//

import Foundation
import Combine

class MonitorViewModel: ObservableObject {
    @Published var mode: MonitorMode = .stats
    @Published var dataStore: DataStore
    @Published var showEditQS: Bool = false
    @Published var showAddQS: Bool = false
    @Published var selectedQSEntry: QSEntry? = nil
    @Published var journalExpanded: Bool = false
    
    enum MonitorMode: String, CaseIterable {
        case stats = "Stats"
        case qs = "QS"
    }
    
    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }
    
    // MARK: - Stats
    
    var streak: Int {
        StatsEngine.currentStreak(from: dataStore.recentLogs(30))
    }
    
    var averageAdherence: Double {
        StatsEngine.averageAdherence(from: dataStore.recentLogs(7))
    }
    
    var last7DaysAdherence: [(date: Date, adherence: Double)] {
        StatsEngine.dailyAdherence(from: dataStore.recentLogs(7), days: 7)
    }
    
    var dailyAdherence: [(date: Date, adherence: Double)] {
        StatsEngine.dailyAdherence(from: dataStore.recentLogs(30), days: 30)
    }
    
    var categoryAverages: [(category: BlockCategory, duration: TimeInterval)] {
        StatsEngine.categoryAverages(from: dataStore.recentLogs(7)).map { (category: $0.key, duration: $0.value) }
    }
    
    var subcategoryAverages: [(name: String, duration: TimeInterval)] {
        StatsEngine.subcategoryAverages(from: dataStore.recentLogs(7)).map { (name: $0.key, duration: $0.value) }
    }
    
    // MARK: - QS
    
    var todayRecords: [QSRecord] {
        let calendar = Calendar.current
        return dataStore.qsRecords.filter { calendar.isDateInToday($0.date) }
    }
    
    var recentRecords: [QSRecord] {
        dataStore.qsRecords
            .sorted { $0.date > $1.date }
            .prefix(50)
            .map { $0 }
    }
    
    /// Group records by day for history view
    var recordsByDay: [(Date, [QSRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: dataStore.qsRecords) { record in
            calendar.startOfDay(for: record.date)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    func recordValue(for entry: QSEntry) -> String? {
        todayRecords.first(where: { $0.entryId == entry.id })?.value
    }
    
    func saveQSValue(_ value: String, for entry: QSEntry) {
        // Remove existing today record for this entry
        let calendar = Calendar.current
        dataStore.qsRecords.removeAll { record in
            record.entryId == entry.id && calendar.isDateInToday(record.date)
        }
        // Add new
        dataStore.addQSRecord(QSRecord(entryId: entry.id, entryName: entry.name, value: value, date: Date()))
    }
    
    func deleteQSEntry(_ entry: QSEntry) {
        dataStore.qsEntries.removeAll { $0.id == entry.id }
        dataStore.qsRecords.removeAll { $0.entryId == entry.id }
    }
    
    func addQSEntry(name: String, inputType: QSInputType, icon: String) {
        let entry = QSEntry(name: name, inputType: inputType, trigger: .none, automation: .proactive, icon: icon)
        dataStore.addQSEntry(entry)
    }
}
