//
//  QSTriggerScheduler.swift
//  CueIn
//
//  Schedules QS reminders based on per-entry trigger settings and live formula state.
//

import Foundation
import Combine
import UIKit
import UserNotifications

final class QSTriggerScheduler: ObservableObject {
    private enum Constants {
        static let notificationPrefix = "qs-trigger-"
        static let firedTriggerKey = "com.cuein.qsTriggerFiredKeys"
    }

    private weak var dataStore: DataStore?
    private weak var engine: FormulaEngine?
    private var cancellables = Set<AnyCancellable>()
    private var hasBound = false
    private var lastObservedStartDate: Date?

    func bind(dataStore: DataStore, engine: FormulaEngine) {
        self.dataStore = dataStore
        self.engine = engine

        guard !hasBound else {
            sync()
            return
        }

        hasBound = true
        lastObservedStartDate = engine.startDate

        let blockCompletionSignature = engine.$blocks
            .map { blocks in
                "\(blocks.count)|\(blocks.filter(\.isChecked).count)"
            }
            .removeDuplicates()
            .map { _ in () }
            .eraseToAnyPublisher()

        let publishers: [AnyPublisher<Void, Never>] = [
            dataStore.$qsEntries.map { _ in () }.eraseToAnyPublisher(),
            dataStore.$qsRecords.map { _ in () }.eraseToAnyPublisher(),
            blockCompletionSignature,
            engine.$isRunning.map { _ in () }.eraseToAnyPublisher(),
            engine.$startDate.map { _ in () }.eraseToAnyPublisher(),
            engine.$targetDuration.map { _ in () }.eraseToAnyPublisher()
        ]

        Publishers.MergeMany(publishers)
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] in
                self?.sync()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                self?.sync()
            }
            .store(in: &cancellables)

        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        sync()
    }

    func sync() {
        guard let dataStore, let engine else { return }

        pruneTriggeredKeys()
        autoCaptureEntriesIfNeeded(dataStore: dataStore, engine: engine)
        fireImmediateTriggersIfNeeded(dataStore: dataStore, engine: engine)
        rebuildPendingNotifications(dataStore: dataStore, engine: engine)
        lastObservedStartDate = engine.startDate
    }

    private func autoCaptureEntriesIfNeeded(dataStore: DataStore, engine: FormulaEngine) {
        guard let startDate = engine.startDate else { return }
        let isFreshStart = lastObservedStartDate == nil || abs(startDate.timeIntervalSince(lastObservedStartDate ?? .distantPast)) > 1
        guard isFreshStart else { return }

        for entry in dataStore.qsEntries where entry.automation == .automatic {
            guard todayRecord(for: entry, in: dataStore) == nil else { continue }

            switch entry.inputType {
            case .time:
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm"
                dataStore.upsertQSRecord(entry: entry, value: formatter.string(from: startDate), for: Date())
            default:
                continue
            }
        }
    }

    private func fireImmediateTriggersIfNeeded(dataStore: DataStore, engine: FormulaEngine) {
        for entry in dataStore.qsEntries {
            guard entry.trigger.isEnabled else { continue }
            guard todayRecord(for: entry, in: dataStore) == nil else { continue }

            switch entry.trigger.kind {
            case .formulaStart:
                guard engine.isRunning, engine.startDate != nil else { continue }
                fireImmediateNotificationIfNeeded(for: entry, reason: "Your schedule just started.", date: Date())
            case .afterFinalBlock:
                guard engine.isRunning, !engine.blocks.isEmpty, engine.blocks.allSatisfy(\.isChecked) else { continue }
                fireImmediateNotificationIfNeeded(for: entry, reason: "You finished the final block. Close the day cleanly.", date: Date())
            case .manual, .scheduledTime, .formulaEnd:
                continue
            }
        }
    }

    private func rebuildPendingNotifications(dataStore: DataStore, engine: FormulaEngine) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { [weak self] requests in
            guard let self else { return }

            let existingIdentifiers = requests
                .map(\.identifier)
                .filter { $0.hasPrefix(Constants.notificationPrefix) }

            center.removePendingNotificationRequests(withIdentifiers: existingIdentifiers)

            let newRequests = self.pendingRequests(dataStore: dataStore, engine: engine)
            for request in newRequests {
                center.add(request, withCompletionHandler: nil)
            }
        }
    }

    private func pendingRequests(dataStore: DataStore, engine: FormulaEngine) -> [UNNotificationRequest] {
        dataStore.qsEntries.compactMap { entry in
            guard entry.trigger.isEnabled else { return nil }
            guard todayRecord(for: entry, in: dataStore) == nil else { return nil }

            switch entry.trigger.kind {
            case .manual, .formulaStart, .afterFinalBlock:
                return nil
            case .scheduledTime:
                return makeScheduledRequest(
                    for: entry,
                    at: nextOccurrence(secondsFromMidnight: entry.trigger.scheduledSecondsFromMidnight, after: Date()),
                    suffix: "scheduled"
                )
            case .formulaEnd:
                guard engine.isRunning, let startDate = engine.startDate else { return nil }
                let endDate = startDate.addingTimeInterval(engine.targetDuration)
                guard endDate > Date() else { return nil }
                return makeScheduledRequest(for: entry, at: endDate, suffix: "formula-end")
            }
        }
    }

    private func makeScheduledRequest(for entry: QSEntry, at date: Date, suffix: String) -> UNNotificationRequest {
        let content = notificationContent(
            for: entry,
            reason: entry.trigger.kind == .formulaEnd ? "Your planned schedule window is ending." : "You asked to be reminded to fill this input."
        )
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let identifier = Constants.notificationPrefix + "\(entry.id.uuidString)-\(suffix)-\(dayKey(for: date))"
        return UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
    }

    private func fireImmediateNotificationIfNeeded(for entry: QSEntry, reason: String, date: Date) {
        let key = triggerFireKey(for: entry, date: date)
        guard !triggeredKeys.contains(key) else { return }

        let content = notificationContent(for: entry, reason: reason)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: Constants.notificationPrefix + "\(entry.id.uuidString)-immediate-\(dayKey(for: date))",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
        markTriggered(key)
    }

    private func notificationContent(for entry: QSEntry, reason: String) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = entry.inputType == .journal ? "Open \(entry.name)" : "Fill \(entry.name)"
        content.body = reason
        content.sound = .default
        return content
    }

    private func todayRecord(for entry: QSEntry, in dataStore: DataStore) -> QSRecord? {
        let calendar = Calendar.current
        return dataStore.qsRecords.first {
            $0.entryId == entry.id && calendar.isDateInToday($0.date)
        }
    }

    private func nextOccurrence(secondsFromMidnight: Double, after date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let candidate = startOfDay.addingTimeInterval(secondsFromMidnight)
        if candidate > date {
            return candidate
        }
        return calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate.addingTimeInterval(24 * 3600)
    }

    private var triggeredKeys: Set<String> {
        Set(UserDefaults.standard.stringArray(forKey: Constants.firedTriggerKey) ?? [])
    }

    private func markTriggered(_ key: String) {
        var keys = triggeredKeys
        keys.insert(key)
        UserDefaults.standard.set(Array(keys), forKey: Constants.firedTriggerKey)
    }

    private func pruneTriggeredKeys() {
        let todayPrefix = dayKey(for: Date())
        let filtered = triggeredKeys.filter { $0.contains(todayPrefix) }
        UserDefaults.standard.set(Array(filtered), forKey: Constants.firedTriggerKey)
    }

    private func triggerFireKey(for entry: QSEntry, date: Date) -> String {
        "\(entry.id.uuidString)|\(entry.trigger.kind.rawValue)|\(dayKey(for: date))"
    }

    private func dayKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
