//
//  DataStore.swift
//  CueIn
//
//  Central data store — single source of truth for all app data.
//  Seed data only runs once (first launch). Resets persist via UserDefaults.
//

import Foundation
import Combine
import UIKit

class DataStore: ObservableObject {
    
    // MARK: - Published Data
    
    @Published var formulas: [Formula] = []
    @Published var weekSchedule: WeekSchedule = WeekSchedule()
    @Published var profile: UserProfile = UserProfile()
    @Published var qsEntries: [QSEntry] = []
    @Published var qsRecords: [QSRecord] = []
    @Published var dayLogs: [DayLog] = []
    @Published var blockLibrary: [BlockLibraryItem] = []
    
    /// User-created subcategories (persisted per category)
    @Published var customSubcategories: [BlockCategory: [String]] = [:]
    
    private static let hasSeededKey = "com.cuein.hasSeeded"
    private static let hasResetAllKey = "com.cuein.hasResetAll"
    private static let persistedSnapshotKey = "com.cuein.persistedDataStore"
    private static let journalPhotoDirectoryName = "QSJournalPhotos"
    
    private var persistenceCancellables = Set<AnyCancellable>()
    private var isHydratingStoredData = true
    private let persistenceQueue = DispatchQueue(label: "com.cuein.datastore.persistence", qos: .utility)

    private struct PersistedSnapshot: Codable {
        var formulas: [Formula]
        var weekSchedule: WeekSchedule
        var profile: UserProfile
        var qsEntries: [QSEntry]
        var qsRecords: [QSRecord]
        var dayLogs: [DayLog]
        var blockLibrary: [BlockLibraryItem]
        var customSubcategories: [String: [String]]

        init(
            formulas: [Formula],
            weekSchedule: WeekSchedule,
            profile: UserProfile,
            qsEntries: [QSEntry],
            qsRecords: [QSRecord],
            dayLogs: [DayLog],
            blockLibrary: [BlockLibraryItem],
            customSubcategories: [String: [String]]
        ) {
            self.formulas = formulas
            self.weekSchedule = weekSchedule
            self.profile = profile
            self.qsEntries = qsEntries
            self.qsRecords = qsRecords
            self.dayLogs = dayLogs
            self.blockLibrary = blockLibrary
            self.customSubcategories = customSubcategories
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            formulas = try container.decode([Formula].self, forKey: .formulas)
            weekSchedule = try container.decode(WeekSchedule.self, forKey: .weekSchedule)
            profile = try container.decode(UserProfile.self, forKey: .profile)
            qsEntries = try container.decode([QSEntry].self, forKey: .qsEntries)
            qsRecords = try container.decode([QSRecord].self, forKey: .qsRecords)
            dayLogs = try container.decode([DayLog].self, forKey: .dayLogs)
            blockLibrary = try container.decodeIfPresent([BlockLibraryItem].self, forKey: .blockLibrary) ?? []
            customSubcategories = try container.decode([String: [String]].self, forKey: .customSubcategories)
        }
    }

    private enum SampleCatalog {
        static let morningRoutineID = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
        static let resetRoutineID = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!
        static let productiveWeekdayID = UUID(uuidString: "33333333-3333-4333-8333-333333333333")!
        static let recoveryDayID = UUID(uuidString: "44444444-4444-4444-8444-444444444444")!
        static let creatorSprintID = UUID(uuidString: "55555555-5555-4555-8555-555555555555")!
        static let workSurgeID = UUID(uuidString: "66666666-6666-4666-8666-666666666666")!
        static let athleticSurgeID = UUID(uuidString: "77777777-7777-4777-8777-777777777777")!

        static let wakeUpEntryID = UUID(uuidString: "aaaaaaa1-aaaa-4aaa-8aaa-aaaaaaaaaaa1")!
        static let sleepEntryID = UUID(uuidString: "aaaaaaa2-aaaa-4aaa-8aaa-aaaaaaaaaaa2")!
        static let moodEntryID = UUID(uuidString: "aaaaaaa3-aaaa-4aaa-8aaa-aaaaaaaaaaa3")!
        static let junkFoodEntryID = UUID(uuidString: "aaaaaaa4-aaaa-4aaa-8aaa-aaaaaaaaaaa4")!
        static let exerciseEntryID = UUID(uuidString: "aaaaaaa5-aaaa-4aaa-8aaa-aaaaaaaaaaa5")!
        static let dailyNoteEntryID = UUID(uuidString: "aaaaaaa6-aaaa-4aaa-8aaa-aaaaaaaaaaa6")!
    }
    
    // MARK: - Init
    
    init() {
        restoreInitialState()
        setupPersistence()
        isHydratingStoredData = false
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

        for day in DayOfWeek.allCases {
            let remainingIDs = weekSchedule.formulaIds(for: day).filter { $0 != id }
            weekSchedule.setFormulaIds(remainingIDs, for: day)
        }
    }
    
    func formula(for id: UUID) -> Formula? {
        formulas.first { $0.id == id }
    }

    func saveBlockLibraryItem(from block: Block) {
        let candidate = BlockLibraryItem(block: block)

        if let existingIndex = blockLibrary.firstIndex(where: { $0.matches(candidate) }) {
            blockLibrary[existingIndex].createdAt = Date()
            return
        }

        blockLibrary.insert(candidate, at: 0)
    }

    func deleteBlockLibraryItem(_ item: BlockLibraryItem) {
        blockLibrary.removeAll { $0.id == item.id }
    }
    
    /// Get today's formula based on the week schedule
    func todayFormula() -> Formula? {
        let today = DayOfWeek.today
        return weekSchedule.formulaIds(for: today)
            .compactMap(formula(for:))
            .first
    }

    func preferredPriority(for category: BlockCategory, on date: Date = Date()) -> BlockPriority? {
        profile.preferredPriority(for: category, on: date)
    }
    
    // MARK: - Day Log
    
    func addDayLog(_ log: DayLog) {
        let calendar = Calendar.current
        guard let existingIndex = dayLogs.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: log.date) }) else {
            dayLogs.append(log)
            return
        }

        dayLogs[existingIndex] = mergeDayLog(dayLogs[existingIndex], with: log)
    }

    func removeDayLog(for date: Date) {
        let calendar = Calendar.current
        dayLogs.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
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

    func updateQSEntry(_ entry: QSEntry) {
        if let index = qsEntries.firstIndex(where: { $0.id == entry.id }) {
            qsEntries[index] = entry
        }
    }

    func deleteQSEntry(_ entry: QSEntry) {
        removeJournalAssets(forEntryID: entry.id)
        qsEntries.removeAll { $0.id == entry.id }
        qsRecords.removeAll { $0.entryId == entry.id }
    }
    
    func addQSRecord(_ record: QSRecord) {
        qsRecords.append(record)
    }

    func qsRecords(for date: Date) -> [QSRecord] {
        let calendar = Calendar.current
        return qsRecords.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func qsRecords(inMonth month: Date) -> [QSRecord] {
        let calendar = Calendar.current
        return qsRecords.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    func removeQSRecords(for date: Date) {
        let calendar = Calendar.current
        let removedRecords = qsRecords.filter { calendar.isDate($0.date, inSameDayAs: date) }
        purgeJournalAssets(in: removedRecords)
        qsRecords.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func upsertQSRecord(entry: QSEntry, value: String, for date: Date) {
        let calendar = Calendar.current
        qsRecords.removeAll { record in
            record.entryId == entry.id && calendar.isDate(record.date, inSameDayAs: date)
        }

        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        qsRecords.append(
            QSRecord(
                entryId: entry.id,
                entryName: entry.name,
                value: value,
                date: date
            )
        )
    }

    func journalContent(for entry: QSEntry, on date: Date) -> QSJournalContent {
        guard let record = qsRecords(for: date).first(where: { $0.entryId == entry.id }) else {
            return QSJournalContent()
        }

        if let data = record.value.data(using: .utf8),
           let content = try? JSONDecoder().decode(QSJournalContent.self, from: data) {
            return content
        }

        return QSJournalContent(text: record.value)
    }

    func saveJournalContent(_ content: QSJournalContent, for entry: QSEntry, on date: Date) {
        let existing = journalContent(for: entry, on: date)
        let removedPhotoNames = Set(existing.photoFileNames).subtracting(content.photoFileNames)
        removedPhotoNames.forEach(deleteJournalPhoto)

        if content.isEmpty {
            let calendar = Calendar.current
            qsRecords.removeAll { record in
                record.entryId == entry.id && calendar.isDate(record.date, inSameDayAs: date)
            }
            return
        }

        guard let data = try? JSONEncoder().encode(content),
              let payload = String(data: data, encoding: .utf8) else { return }

        upsertQSRecord(entry: entry, value: payload, for: date)
    }

    func saveJournalPhoto(_ image: UIImage) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.85) else { return nil }
        let fileName = UUID().uuidString + ".jpg"
        let directory = journalPhotoDirectoryURL()
        let url = directory.appendingPathComponent(fileName)

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            try data.write(to: url, options: [.atomic])
            return fileName
        } catch {
            return nil
        }
    }

    func journalPhotoURL(for fileName: String) -> URL {
        journalPhotoDirectoryURL().appendingPathComponent(fileName)
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

    func installTestingSamples() {
        let sampleBundle = makeSampleBundle()

        mergeProfileIfNeeded(sampleBundle.profile)
        upsertFormulas(sampleBundle.formulas)
        mergeSampleSchedule(sampleBundle.schedule)
        upsertQSEntries(sampleBundle.qsEntries)
        mergeCustomSubcategories(sampleBundle.customSubcategories)

        if dayLogs.isEmpty {
            dayLogs = sampleBundle.dayLogs
        }

        UserDefaults.standard.removeObject(forKey: FormulaEngine.stateKey)
    }
    
    // MARK: - Reset & Data Management
    
    /// Reset history only — keeps formulas, schedule, goals
    func resetHistory() {
        purgeJournalAssets(in: qsRecords)
        dayLogs.removeAll()
        qsRecords.removeAll()
    }
    
    /// Full reset — everything back to empty. Prevents re-seeding.
    func resetAll() {
        formulas.removeAll()
        weekSchedule = WeekSchedule()
        profile = UserProfile()
        purgeJournalAssets(in: qsRecords)
        qsEntries.removeAll()
        qsRecords.removeAll()
        dayLogs.removeAll()
        blockLibrary.removeAll()
        customSubcategories.removeAll()
        
        // Prevent seed data from coming back
        UserDefaults.standard.set(true, forKey: Self.hasResetAllKey)
        UserDefaults.standard.removeObject(forKey: Self.persistedSnapshotKey)
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
        let sampleBundle = makeSampleBundle()
        profile = sampleBundle.profile
        formulas = sampleBundle.formulas
        weekSchedule = sampleBundle.schedule
        qsEntries = sampleBundle.qsEntries
        blockLibrary = []
        customSubcategories = sampleBundle.customSubcategories
        dayLogs = sampleBundle.dayLogs
    }

    private func restoreInitialState() {
        if restorePersistedSnapshot() {
            UserDefaults.standard.set(true, forKey: Self.hasSeededKey)
            return
        }

        let hasResetAll = UserDefaults.standard.bool(forKey: Self.hasResetAllKey)
        guard !hasResetAll else { return }

        seedSampleData()
        UserDefaults.standard.set(true, forKey: Self.hasSeededKey)
        savePersistedSnapshot()
    }

    private func setupPersistence() {
        let publishers: [AnyPublisher<Void, Never>] = [
            $formulas.map { _ in () }.eraseToAnyPublisher(),
            $weekSchedule.map { _ in () }.eraseToAnyPublisher(),
            $profile.map { _ in () }.eraseToAnyPublisher(),
            $qsEntries.map { _ in () }.eraseToAnyPublisher(),
            $qsRecords.map { _ in () }.eraseToAnyPublisher(),
            $dayLogs.map { _ in () }.eraseToAnyPublisher(),
            $blockLibrary.map { _ in () }.eraseToAnyPublisher(),
            $customSubcategories.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(publishers)
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.savePersistedSnapshotIfNeeded()
            }
            .store(in: &persistenceCancellables)
    }

    private func savePersistedSnapshotIfNeeded() {
        guard !isHydratingStoredData else { return }
        savePersistedSnapshot()
    }

    private func savePersistedSnapshot() {
        let snapshot = PersistedSnapshot(
            formulas: formulas,
            weekSchedule: weekSchedule,
            profile: profile,
            qsEntries: qsEntries,
            qsRecords: qsRecords,
            dayLogs: dayLogs,
            blockLibrary: blockLibrary,
            customSubcategories: Dictionary(
                uniqueKeysWithValues: customSubcategories.map { ($0.key.rawValue, $0.value) }
            )
        )

        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        persistenceQueue.async {
            UserDefaults.standard.set(data, forKey: Self.persistedSnapshotKey)
        }
    }

    @discardableResult
    private func restorePersistedSnapshot() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.persistedSnapshotKey),
              let snapshot = try? JSONDecoder().decode(PersistedSnapshot.self, from: data) else {
            return false
        }

        formulas = snapshot.formulas
        weekSchedule = snapshot.weekSchedule
        profile = snapshot.profile
        qsEntries = snapshot.qsEntries
        qsRecords = snapshot.qsRecords
        dayLogs = snapshot.dayLogs
        blockLibrary = snapshot.blockLibrary.sorted { $0.createdAt > $1.createdAt }
        customSubcategories = snapshot.customSubcategories.reduce(into: [:]) { partialResult, item in
            guard let category = BlockCategory(rawValue: item.key) else { return }
            partialResult[category] = item.value
        }
        return true
    }

    private struct SampleBundle {
        let profile: UserProfile
        let formulas: [Formula]
        let schedule: WeekSchedule
        let qsEntries: [QSEntry]
        let customSubcategories: [BlockCategory: [String]]
        let dayLogs: [DayLog]
    }

    private func makeSampleBundle() -> SampleBundle {
        let morningRoutine = Formula(
            id: SampleCatalog.morningRoutineID,
            name: "Morning Routine",
            targetDuration: 45 * 60,
            blocks: [
                Block(name: "Morning Run", duration: 15 * 60, category: .sport, subcategory: "Cardio", priority: .medium, flowLogic: .flowing, colorHex: "34D399"),
                Block(name: "Cold Shower", duration: 5 * 60, category: .wellness, subcategory: "Cold Shower", priority: .low, flowLogic: .flowing, colorHex: "F472B6"),
                Block(name: "Meditation", duration: 10 * 60, category: .wellness, subcategory: "Meditation", priority: .medium, flowLogic: .flowing, colorHex: "F472B6"),
                Block(name: "Breakfast", duration: 15 * 60, category: .wellness, subcategory: "Breakfast", priority: .low, flowLogic: .flowing, colorHex: "FBBF24")
            ],
            type: .mini,
            emoji: "🌅"
        )

        let resetRoutine = Formula(
            id: SampleCatalog.resetRoutineID,
            name: "Reset Routine",
            targetDuration: 20 * 60,
            blocks: [
                Block(name: "Breathing Reset", duration: 5 * 60, category: .wellness, subcategory: "Breathing", priority: .medium, flowLogic: .flowing, colorHex: "F472B6"),
                Block(name: "Walk the Block", duration: 10 * 60, category: .sport, subcategory: "Walking", priority: .medium, flowLogic: .flowing, colorHex: "34D399"),
                Block(name: "Quick Journal", duration: 5 * 60, category: .wellness, subcategory: "Journaling", priority: .low, flowLogic: .blocking, colorHex: "FBBF24")
            ],
            type: .mini,
            emoji: "🧩"
        )

        let productiveWeekday = Formula(
            id: SampleCatalog.productiveWeekdayID,
            name: "Productive Weekday",
            targetDuration: 16 * 3600,
            blocks: [
                Block(name: "Morning Routine", duration: 45 * 60, category: .wellness, priority: .high, flowLogic: .blocking, colorHex: "F472B6", miniFormulaId: morningRoutine.id),
                Block(name: "Deep Work", duration: 2 * 3600, category: .work, subcategory: "Deep Work", priority: .high, flowLogic: .blocking, colorHex: "6C63FF"),
                Block(name: "Study Session", duration: 90 * 60, category: .study, subcategory: "Computer Science", priority: .high, flowLogic: .blocking, colorHex: "60A5FA"),
                Block(name: "Lunch Break", duration: 30 * 60, category: .wellness, subcategory: "Lunch", priority: .low, flowLogic: .flowing, colorHex: "FBBF24"),
                Block(name: "Creative Work", duration: 90 * 60, category: .work, subcategory: "Creative Work", priority: .medium, flowLogic: .flowing, colorHex: "A78BFA"),
                Block(name: "Admin Sweep", duration: 60 * 60, category: .work, subcategory: "Shallow Work", priority: .low, flowLogic: .flowing, colorHex: "9CA3AF"),
                Block(name: "Training", duration: 60 * 60, category: .sport, subcategory: "Resistance Training", priority: .medium, flowLogic: .blocking, colorHex: "34D399"),
                Block(name: "Reading", duration: 45 * 60, category: .study, subcategory: "Languages", priority: .low, flowLogic: .flowing, colorHex: "60A5FA"),
                Block(name: "Evening Wind-down", duration: 30 * 60, category: .wellness, subcategory: "Journaling", priority: .low, flowLogic: .flowing, colorHex: "F472B6")
            ],
            type: .full,
            emoji: "⚡"
        )

        let creatorSprint = Formula(
            id: SampleCatalog.creatorSprintID,
            name: "Creator Sprint",
            targetDuration: 15 * 3600,
            blocks: [
                Block(name: "Reset Routine", duration: 20 * 60, category: .wellness, priority: .high, flowLogic: .blocking, colorHex: "F472B6", miniFormulaId: resetRoutine.id),
                Block(name: "Script Writing", duration: 90 * 60, category: .work, subcategory: "Creative Work", priority: .high, flowLogic: .blocking, colorHex: "A78BFA"),
                Block(name: "Recording Session", duration: 2 * 3600, category: .work, subcategory: "Production", priority: .high, flowLogic: .blocking, colorHex: "6C63FF"),
                Block(name: "Edit Pass", duration: 90 * 60, category: .work, subcategory: "Editing", priority: .medium, flowLogic: .flowing, colorHex: "9CA3AF"),
                Block(name: "Gym", duration: 75 * 60, category: .sport, subcategory: "Resistance Training", priority: .medium, flowLogic: .blocking, colorHex: "34D399"),
                Block(name: "Language Deck", duration: 30 * 60, category: .study, subcategory: "Languages", priority: .low, flowLogic: .flowing, colorHex: "60A5FA"),
                Block(name: "Inbox Zero", duration: 30 * 60, category: .custom, subcategory: "Admin", priority: .low, flowLogic: .flowing, colorHex: "FBBF24")
            ],
            type: .full,
            emoji: "🎬"
        )

        let recoveryDay = Formula(
            id: SampleCatalog.recoveryDayID,
            name: "Recovery Day",
            targetDuration: 14 * 3600,
            blocks: [
                Block(name: "Sleep In", duration: 60 * 60, category: .wellness, subcategory: "Recovery", priority: .medium, flowLogic: .flowing, colorHex: "F472B6"),
                Block(name: "Light Stretch", duration: 30 * 60, category: .sport, subcategory: "Stretching", priority: .low, flowLogic: .flowing, colorHex: "34D399"),
                Block(name: "Brunch", duration: 45 * 60, category: .wellness, subcategory: "Brunch", priority: .low, flowLogic: .flowing, colorHex: "FBBF24"),
                Block(name: "Creative Projects", duration: 2 * 3600, category: .work, subcategory: "Creative Work", priority: .medium, flowLogic: .flowing, colorHex: "A78BFA"),
                Block(name: "Free Time", duration: 3 * 3600, category: .custom, subcategory: "Free Time", priority: .low, flowLogic: .flowing, colorHex: "FBBF24"),
                Block(name: "Light Reading", duration: 60 * 60, category: .study, subcategory: "Reading", priority: .low, flowLogic: .flowing, colorHex: "60A5FA")
            ],
            type: .full,
            emoji: "🌿"
        )

        let profile = UserProfile(
            stageName: "Building My System",
            goals: [],
            surges: [
                Surge(
                    id: SampleCatalog.workSurgeID,
                    title: "Creator Output Surge",
                    objective: "Protect a 30-day push around work and study so the day bends toward shipping and learning, not drift.",
                    focusCategories: [.work, .study],
                    startDate: Calendar.current.date(byAdding: .day, value: -6, to: Date()) ?? Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 23, to: Date()) ?? Date()
                ),
                Surge(
                    id: SampleCatalog.athleticSurgeID,
                    title: "Conditioning Reset",
                    objective: "Use a shorter sport-focused surge to get consistent sessions back into the week.",
                    focusCategories: [.sport, .wellness],
                    startDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()) ?? Date(),
                    endDate: Calendar.current.date(byAdding: .day, value: 32, to: Date()) ?? Date()
                )
            ],
            dailyTargetHours: 16
        )

        let qsEntries = [
            QSEntry(id: SampleCatalog.wakeUpEntryID, name: "Wake-up Time", inputType: .time, trigger: .formulaStart, automation: .automatic, icon: "sunrise"),
            QSEntry(id: SampleCatalog.sleepEntryID, name: "Sleep Duration", inputType: .number, trigger: .morning, automation: .proactive, icon: "moon.zzz"),
            QSEntry(id: SampleCatalog.moodEntryID, name: "Mood", inputType: .options, trigger: .formulaEnd, automation: .proactive, options: ["😊 Great", "🙂 Good", "😐 Okay", "😟 Low", "😞 Bad"], icon: "face.smiling"),
            QSEntry(id: SampleCatalog.junkFoodEntryID, name: "Junk Food", inputType: .boolean, trigger: .evening, automation: .proactive, defaultTrue: true, icon: "fork.knife"),
            QSEntry(id: SampleCatalog.exerciseEntryID, name: "Exercise Done", inputType: .boolean, trigger: .finalBlock, automation: .proactive, icon: "figure.walk"),
            QSEntry(id: SampleCatalog.dailyNoteEntryID, name: "Daily Journal", inputType: .journal, trigger: .finalBlock, automation: .proactive, icon: "book.closed")
        ]

        var schedule = WeekSchedule(name: "Standard Week")
        schedule.setFormulaIds([productiveWeekday.id], for: .monday)
        schedule.setFormulaIds([productiveWeekday.id], for: .tuesday)
        schedule.setFormulaIds([creatorSprint.id], for: .wednesday)
        schedule.setFormulaIds([productiveWeekday.id], for: .thursday)
        schedule.setFormulaIds([creatorSprint.id], for: .friday)
        schedule.setFormulaIds([recoveryDay.id], for: .saturday)
        schedule.setFormulaIds([recoveryDay.id], for: .sunday)
        schedule.updateAssignment(
            for: .monday,
            title: "Deep Output Day",
            details: "Protect the morning for deep work and keep admin late.",
            formulaIds: [productiveWeekday.id]
        )
        schedule.updateAssignment(
            for: .wednesday,
            title: "Creator Push",
            details: "Use the creator sprint when you need more recording or production work.",
            formulaIds: [creatorSprint.id]
        )
        schedule.updateAssignment(
            for: .saturday,
            title: "Recovery Reset",
            details: "Lighter day with more recovery, reading, and free time.",
            formulaIds: [recoveryDay.id]
        )

        return SampleBundle(
            profile: profile,
            formulas: [morningRoutine, resetRoutine, productiveWeekday, creatorSprint, recoveryDay],
            schedule: schedule,
            qsEntries: qsEntries,
            customSubcategories: [
                .work: ["Deep Work", "Creative Work", "Editing", "Production", "Shallow Work"],
                .sport: ["Cardio", "Resistance Training", "Stretching", "Walking"],
                .wellness: ["Meditation", "Cold Shower", "Journaling", "Breathing", "Recovery"],
                .study: ["Computer Science", "Languages", "Reading"],
                .custom: ["Admin", "Free Time"]
            ],
            dayLogs: makeSampleDayLogs(formulaId: productiveWeekday.id, formulaName: productiveWeekday.name)
        )
    }

    private func makeSampleDayLogs(formulaId: UUID, formulaName: String) -> [DayLog] {
        var logs: [DayLog] = []
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
                    wasChecked: i < checkedBlocks,
                    commitmentRating: i < checkedBlocks ? Int.random(in: 3...5) : nil
                ))
            }
            
            logs.append(DayLog(
                date: date,
                formulaId: formulaId,
                formulaName: formulaName,
                blockLogs: blockLogs,
                targetDuration: 16 * 3600
            ))
        }
        return logs
    }

    private func mergeProfileIfNeeded(_ sampleProfile: UserProfile) {
        if profile.stageName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            profile.stageName = sampleProfile.stageName
        }

        if profile.goals.isEmpty {
            profile.goals = sampleProfile.goals
        }

        if profile.surges.isEmpty {
            profile.surges = sampleProfile.surges
        }

        if profile.dailyTargetHours == 0 {
            profile.dailyTargetHours = sampleProfile.dailyTargetHours
        }
    }

    private func upsertFormulas(_ sampleFormulas: [Formula]) {
        for formula in sampleFormulas {
            if !formulas.contains(where: { $0.id == formula.id }) {
                formulas.append(formula)
            }
        }
    }

    private func upsertQSEntries(_ sampleEntries: [QSEntry]) {
        for entry in sampleEntries {
            if let index = qsEntries.firstIndex(where: { $0.id == entry.id }) {
                qsEntries[index] = entry
            } else {
                qsEntries.append(entry)
            }
        }
    }

    private func mergeCustomSubcategories(_ sampleSubcategories: [BlockCategory: [String]]) {
        for (category, names) in sampleSubcategories {
            var existing = Set(customSubcategories[category] ?? [])
            existing.formUnion(names)
            customSubcategories[category] = existing.sorted()
        }
    }

    private func mergeDayLog(_ existing: DayLog, with incoming: DayLog) -> DayLog {
        let mergedFormulaName: String
        if existing.formulaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            mergedFormulaName = incoming.formulaName
        } else if incoming.formulaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || existing.formulaName == incoming.formulaName {
            mergedFormulaName = existing.formulaName
        } else {
            mergedFormulaName = "Mixed Day"
        }

        let mergedStart: Date?
        switch (existing.startedAt, incoming.startedAt) {
        case let (lhs?, rhs?): mergedStart = min(lhs, rhs)
        case let (lhs?, nil): mergedStart = lhs
        case let (nil, rhs?): mergedStart = rhs
        case (nil, nil): mergedStart = nil
        }

        return DayLog(
            id: existing.id,
            date: existing.date,
            formulaId: existing.formulaId == incoming.formulaId ? existing.formulaId : nil,
            formulaName: mergedFormulaName,
            blockLogs: existing.blockLogs + incoming.blockLogs,
            startedAt: mergedStart,
            targetDuration: existing.targetDuration + incoming.targetDuration
        )
    }

    private func mergeSampleSchedule(_ sampleSchedule: WeekSchedule) {
        for day in DayOfWeek.allCases {
            if weekSchedule.formulaIds(for: day).isEmpty {
                weekSchedule.setFormulaIds(sampleSchedule.formulaIds(for: day), for: day)
            }
        }

        if todayFormula() == nil {
            let today = DayOfWeek.today
            weekSchedule.setFormulaIds(sampleSchedule.formulaIds(for: today), for: today)
        }
    }

    private func journalPhotoDirectoryURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.journalPhotoDirectoryName, isDirectory: true)
    }

    private func deleteJournalPhoto(named fileName: String) {
        let url = journalPhotoDirectoryURL().appendingPathComponent(fileName)
        try? FileManager.default.removeItem(at: url)
    }

    private func purgeJournalAssets(in records: [QSRecord]) {
        records
            .compactMap { record -> QSJournalContent? in
                guard let data = record.value.data(using: .utf8) else { return nil }
                return try? JSONDecoder().decode(QSJournalContent.self, from: data)
            }
            .flatMap(\.photoFileNames)
            .forEach(deleteJournalPhoto)
    }

    private func removeJournalAssets(forEntryID entryID: UUID) {
        purgeJournalAssets(in: qsRecords.filter { $0.entryId == entryID })
    }
}
