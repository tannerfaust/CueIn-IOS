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
    @Published var showEditQS: Bool = false
    @Published var showAddQS: Bool = false
    @Published var selectedQSEntry: QSEntry? = nil
    @Published var journalExpanded: Bool = false
    @Published var journalEditorEntry: QSEntry? = nil
    @Published var journalEditorDate: Date = Date()

    @Published private(set) var streak: Int = 0
    @Published private(set) var averageAdherence: Double = 0
    @Published private(set) var last7DaysAdherence: [(date: Date, adherence: Double)] = []
    @Published private(set) var dailyAdherence: [(date: Date, adherence: Double)] = []
    @Published private(set) var categoryAverages: [(category: BlockCategory, duration: TimeInterval)] = []
    @Published private(set) var subcategoryAverages: [(name: String, duration: TimeInterval)] = []
    @Published private(set) var averageCommitment: Double = 0
    @Published private(set) var categoryCommitmentAverages: [(category: BlockCategory, commitment: Double)] = []

    @Published private(set) var hasLiveSessionMetrics: Bool = false
    @Published private(set) var liveFormulaName: String = "Today"
    @Published private(set) var liveCurrentBlockName: String = "No active block"
    @Published private(set) var liveCompletion: Double = 0
    @Published private(set) var liveCheckedLabel: String = "0/0 done"
    @Published private(set) var liveElapsedLabel: String = "0m"
    @Published private(set) var liveRemainingLabel: String = "0m"
    @Published private(set) var hasLiveCommitment: Bool = false
    @Published private(set) var liveCommitmentLabel: String = "--"
    @Published private(set) var liveCategoryAllocations: [CategoryAllocation] = []

    @Published private(set) var todayRecords: [QSRecord] = []
    @Published private(set) var recentRecords: [QSRecord] = []
    @Published private(set) var recordsByDay: [(Date, [QSRecord])] = []

    let dataStore: DataStore
    let engine: FormulaEngine
    private var cancellables = Set<AnyCancellable>()

    private var liveDayLogCache: DayLog?
    private var logsByDay: [Date: DayLog] = [:]
    private var qsRecordsByDayCache: [Date: [QSRecord]] = [:]
    private var todayRecordByEntryID: [UUID: QSRecord] = [:]
    
    enum MonitorMode: String, CaseIterable {
        case stats = "Stats"
        case qs = "QS"
    }
    
    init(dataStore: DataStore, engine: FormulaEngine) {
        self.dataStore = dataStore
        self.engine = engine

        bindRefreshPipeline()
        refreshData()
    }

    var liveCompletionLabel: String {
        "\(Int((liveCompletion * 100).rounded()))%"
    }

    // MARK: - QS

    func historyLog(for date: Date) -> DayLog? {
        logsByDay[Calendar.current.startOfDay(for: date)]
    }

    func historyQSRecords(for date: Date) -> [QSRecord] {
        qsRecordsByDayCache[Calendar.current.startOfDay(for: date)] ?? []
    }

    func historyQSValue(for entry: QSEntry, on date: Date) -> String? {
        historyQSRecords(for: date).first(where: { $0.entryId == entry.id })?.value
    }

    func saveQSValue(_ value: String, for entry: QSEntry, on date: Date) {
        dataStore.upsertQSRecord(entry: entry, value: value, for: date)
        refreshData()
    }

    func removeHistory(for date: Date) {
        dataStore.removeDayLog(for: date)
        dataStore.removeQSRecords(for: date)
        refreshData()
    }
    
    func recordValue(for entry: QSEntry) -> String? {
        todayRecordByEntryID[entry.id]?.value
    }
    
    func saveQSValue(_ value: String, for entry: QSEntry) {
        dataStore.upsertQSRecord(entry: entry, value: value, for: Date())
        refreshData()
    }

    func journalContent(for entry: QSEntry, on date: Date = Date()) -> QSJournalContent {
        dataStore.journalContent(for: entry, on: date)
    }

    func saveJournalContent(_ content: QSJournalContent, for entry: QSEntry, on date: Date = Date()) {
        dataStore.saveJournalContent(content, for: entry, on: date)
        refreshData()
    }

    func deleteQSEntry(_ entry: QSEntry) {
        dataStore.deleteQSEntry(entry)
        refreshData()
    }

    func addQSEntry(_ entry: QSEntry) {
        dataStore.addQSEntry(entry)
        refreshData()
    }

    func updateQSEntry(_ entry: QSEntry) {
        dataStore.updateQSEntry(entry)
        refreshData()
    }

    func createEntry(
        name: String,
        inputType: QSInputType,
        icon: String,
        trigger: QSTriggerSettings = .none,
        automation: QSAutomation = .proactive,
        options: [String] = [],
        defaultTrue: Bool = false
    ) -> QSEntry {
        QSEntry(
            name: name,
            inputType: inputType,
            trigger: trigger,
            automation: automation,
            options: options,
            defaultTrue: defaultTrue,
            icon: icon
        )
    }

    func formattedQSRecordValue(_ record: QSRecord, for entry: QSEntry?) -> String {
        guard let entry else { return record.value }

        switch entry.inputType {
        case .journal:
            return dataStore.journalContent(for: entry, on: record.date).previewText
        default:
            return record.value
        }
    }

    // MARK: - Refresh

    private func bindRefreshPipeline() {
        let dataStorePublishers: [AnyPublisher<Void, Never>] = [
            dataStore.$dayLogs.map { _ in () }.eraseToAnyPublisher(),
            dataStore.$qsEntries.map { _ in () }.eraseToAnyPublisher(),
            dataStore.$qsRecords.map { _ in () }.eraseToAnyPublisher()
        ]

        let enginePublishers: [AnyPublisher<Void, Never>] = [
            engine.$isRunning.map { _ in () }.eraseToAnyPublisher(),
            engine.$blocks.map { _ in () }.eraseToAnyPublisher(),
            engine.$currentBlockIndex.map { _ in () }.eraseToAnyPublisher(),
            engine.$elapsedTotal.map { _ in () }.eraseToAnyPublisher(),
            engine.$targetDuration.map { _ in () }.eraseToAnyPublisher(),
            engine.$startDate.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(dataStorePublishers + enginePublishers)
            .debounce(for: .milliseconds(120), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.refreshData()
            }
            .store(in: &cancellables)
    }

    private func refreshData() {
        refreshLiveStats()
        refreshHistoryCaches()
        refreshQSCache()
    }

    private func refreshLiveStats() {
        liveFormulaName = engine.formulaName.isEmpty ? "Today" : engine.formulaName
        liveCurrentBlockName = engine.currentBlock?.name ?? "No active block"
        liveCheckedLabel = "\(engine.totalChecked)/\(engine.blocks.count) done"
        liveElapsedLabel = engine.formattedElapsed
        liveRemainingLabel = engine.formattedRemaining

        liveDayLogCache = makeLiveDayLog()
        hasLiveSessionMetrics = liveDayLogCache != nil
        liveCompletion = liveDayLogCache?.adherence ?? 0

        if let liveDayLogCache {
            hasLiveCommitment = liveDayLogCache.blockLogs.contains { $0.commitmentRating != nil }
            if hasLiveCommitment {
                let liveCommitment = StatsEngine.averageCommitment(from: [liveDayLogCache])
                liveCommitmentLabel = "\(Int((liveCommitment * 100).rounded()))%"
            } else {
                liveCommitmentLabel = "--"
            }

            let durations = liveDayLogCache.categoryDurations
            let total = durations.values.reduce(0, +)
            if total > 0 {
                liveCategoryAllocations = BlockCategory.allCases.compactMap { category in
                    guard let duration = durations[category], duration > 0 else { return nil }
                    return CategoryAllocation(category: category, duration: duration, totalDuration: total)
                }
            } else {
                liveCategoryAllocations = []
            }
        } else {
            hasLiveCommitment = false
            liveCommitmentLabel = "--"
            liveCategoryAllocations = []
        }
    }

    private func refreshHistoryCaches() {
        let calendar = Calendar.current
        var effectiveLogs = dataStore.dayLogs

        if let liveDayLogCache {
            effectiveLogs.removeAll { calendar.isDate($0.date, inSameDayAs: liveDayLogCache.date) }
            effectiveLogs.append(liveDayLogCache)
        }

        let sortedLogs = effectiveLogs.sorted { $0.date > $1.date }
        logsByDay = Dictionary(
            uniqueKeysWithValues: sortedLogs.map { (calendar.startOfDay(for: $0.date), $0) }
        )

        let recent7 = Array(sortedLogs.prefix(7))
        let recent30 = Array(sortedLogs.prefix(30))

        streak = StatsEngine.currentStreak(from: recent30)
        averageAdherence = StatsEngine.averageAdherence(from: recent7)
        last7DaysAdherence = StatsEngine.dailyAdherence(from: recent7, days: 7)
        dailyAdherence = StatsEngine.dailyAdherence(from: recent30, days: 30)
        categoryAverages = StatsEngine.categoryAverages(from: recent7).map { (category: $0.key, duration: $0.value) }
        subcategoryAverages = StatsEngine.subcategoryAverages(from: recent7).map { (name: $0.key, duration: $0.value) }
        averageCommitment = StatsEngine.averageCommitment(from: recent7)
        categoryCommitmentAverages = StatsEngine.categoryCommitmentAverages(from: recent7)
            .map { (category: $0.key, commitment: $0.value) }
    }

    private func refreshQSCache() {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: dataStore.qsRecords) { record in
            calendar.startOfDay(for: record.date)
        }

        qsRecordsByDayCache = grouped.mapValues { records in
            records.sorted { lhs, rhs in
                if lhs.entryName == rhs.entryName {
                    return lhs.date > rhs.date
                }
                return lhs.entryName < rhs.entryName
            }
        }

        let todayKey = calendar.startOfDay(for: Date())
        todayRecords = qsRecordsByDayCache[todayKey] ?? []
        todayRecordByEntryID = Dictionary(uniqueKeysWithValues: todayRecords.map { ($0.entryId, $0) })
        recentRecords = Array(dataStore.qsRecords.sorted { $0.date > $1.date }.prefix(50))
        recordsByDay = qsRecordsByDayCache
            .sorted { $0.key > $1.key }
            .map { ($0.key, $0.value) }
    }

    private func makeLiveDayLog() -> DayLog? {
        let hasLiveProgress =
            engine.isRunning ||
            engine.elapsedTotal > 0 ||
            engine.totalChecked > 0 ||
            engine.blocks.contains { $0.commitmentRating != nil }

        guard hasLiveProgress, !engine.blocks.isEmpty else { return nil }
        return engine.generateDayLog(synchronizeIfRunning: false)
    }
}
