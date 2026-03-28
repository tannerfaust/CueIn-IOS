//
//  StatsEngine.swift
//  CueIn
//
//  Computes analytics — averages, adherence, streaks.
//

import Foundation

struct SurgeDayProgress: Identifiable {
    let date: Date
    let plannedFocusDuration: TimeInterval
    let effectiveFocusDuration: TimeInterval
    let fulfillmentRatio: Double
    let commitmentRatio: Double
    let wasOnTarget: Bool

    var id: Date { date }
}

struct SurgeProgressSnapshot {
    let surge: Surge
    let elapsedDays: Int
    let totalDays: Int
    let plannedFocusDuration: TimeInterval
    let effectiveFocusDuration: TimeInterval
    let fulfillmentRatio: Double
    let commitmentRatio: Double
    let onTargetRatio: Double
    let dayProgress: [SurgeDayProgress]

    var remainingDays: Int {
        max(0, totalDays - elapsedDays)
    }

    var timeProgressRatio: Double {
        guard totalDays > 0 else { return 0 }
        return min(1, Double(elapsedDays) / Double(totalDays))
    }
}

class StatsEngine {
    
    // MARK: - Adherence
    
    /// Daily adherence values for the last N days (0.0–1.0)
    static func dailyAdherence(from logs: [DayLog], days: Int = 30) -> [(date: Date, adherence: Double)] {
        let sorted = logs.sorted { $0.date > $1.date }
        return Array(sorted.prefix(days)).map { ($0.date, $0.adherence) }
    }
    
    /// Average adherence across all logs
    static func averageAdherence(from logs: [DayLog]) -> Double {
        guard !logs.isEmpty else { return 0 }
        return logs.reduce(0) { $0 + $1.adherence } / Double(logs.count)
    }
    
    // MARK: - Category Averages
    
    /// Average hours per day for each category
    static func categoryAverages(from logs: [DayLog]) -> [BlockCategory: TimeInterval] {
        guard !logs.isEmpty else { return [:] }
        
        var totals: [BlockCategory: TimeInterval] = [:]
        for log in logs {
            for (cat, dur) in log.categoryDurations {
                totals[cat, default: 0] += dur
            }
        }
        
        // Average per day
        return totals.mapValues { $0 / Double(logs.count) }
    }
    
    /// Average hours per day for each subcategory
    static func subcategoryAverages(from logs: [DayLog]) -> [String: TimeInterval] {
        guard !logs.isEmpty else { return [:] }
        
        var totals: [String: TimeInterval] = [:]
        for log in logs {
            for (sub, dur) in log.subcategoryDurations {
                totals[sub, default: 0] += dur
            }
        }
        
        return totals.mapValues { $0 / Double(logs.count) }
    }

    // MARK: - Commitment

    static func averageCommitment(from logs: [DayLog]) -> Double {
        weightedCommitment(from: logs.flatMap(\.blockLogs))
    }

    static func categoryCommitmentAverages(from logs: [DayLog]) -> [BlockCategory: Double] {
        let entries = logs.flatMap(\.blockLogs).filter { $0.wasChecked }
        let grouped = Dictionary(grouping: entries, by: \.category)
        return grouped.mapValues { weightedCommitment(from: $0) }
    }

    // MARK: - Surge Analytics

    static func surgeProgress(for surge: Surge, logs: [DayLog], asOf date: Date = Date()) -> SurgeProgressSnapshot {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: surge.startDate)
        let fullEnd = calendar.startOfDay(for: surge.endDate)
        let today = calendar.startOfDay(for: date)

        let cappedEnd = min(fullEnd, today)
        let elapsedDays = today < start ? 0 : max(1, (calendar.dateComponents([.day], from: start, to: cappedEnd).day ?? 0) + 1)
        let totalDays = max(1, surge.durationDays)

        guard elapsedDays > 0 else {
            return SurgeProgressSnapshot(
                surge: surge,
                elapsedDays: 0,
                totalDays: totalDays,
                plannedFocusDuration: 0,
                effectiveFocusDuration: 0,
                fulfillmentRatio: 0,
                commitmentRatio: 0,
                onTargetRatio: 0,
                dayProgress: []
            )
        }

        let focusCategories = Set(surge.focusCategories)
        let days: [Date] = (0..<elapsedDays).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: start)
        }

        let points: [SurgeDayProgress] = days.map { day in
            let dayEntries = logs
                .first(where: { calendar.isDate($0.date, inSameDayAs: day) })?
                .blockLogs
                .filter { focusCategories.contains($0.category) } ?? []

            let planned = dayEntries.reduce(0.0) { $0 + $1.scheduledDuration }
            let effective = dayEntries.reduce(0.0) { $0 + $1.effectiveDuration }
            let fulfillment = planned > 0 ? min(1.25, max(0, effective / planned)) : 0
            let commitment = weightedCommitment(from: dayEntries)

            return SurgeDayProgress(
                date: day,
                plannedFocusDuration: planned,
                effectiveFocusDuration: effective,
                fulfillmentRatio: fulfillment,
                commitmentRatio: commitment,
                wasOnTarget: planned > 0 && fulfillment >= 0.8
            )
        }

        let plannedTotal = points.reduce(0.0) { $0 + $1.plannedFocusDuration }
        let effectiveTotal = points.reduce(0.0) { $0 + $1.effectiveFocusDuration }
        let fulfillmentRatio = plannedTotal > 0 ? min(1.25, max(0, effectiveTotal / plannedTotal)) : 0
        let onTargetDays = points.filter(\.wasOnTarget).count

        return SurgeProgressSnapshot(
            surge: surge,
            elapsedDays: elapsedDays,
            totalDays: totalDays,
            plannedFocusDuration: plannedTotal,
            effectiveFocusDuration: effectiveTotal,
            fulfillmentRatio: fulfillmentRatio,
            commitmentRatio: weightedCommitment(from: logs
                .filter { surge.includes($0.date, calendar: calendar) && calendar.startOfDay(for: $0.date) <= cappedEnd }
                .flatMap(\.blockLogs)
                .filter { focusCategories.contains($0.category) }),
            onTargetRatio: elapsedDays > 0 ? Double(onTargetDays) / Double(elapsedDays) : 0,
            dayProgress: points
        )
    }

    private static func weightedCommitment(from entries: [BlockLogEntry]) -> Double {
        let ratedEntries = entries.filter { $0.wasChecked && $0.commitmentRatio != nil && $0.actualDuration > 0 }
        guard !ratedEntries.isEmpty else { return 0 }

        let totalActual = ratedEntries.reduce(0.0) { $0 + $1.actualDuration }
        guard totalActual > 0 else { return 0 }

        let totalEffective = ratedEntries.reduce(0.0) { $0 + $1.effectiveDuration }
        return min(1, max(0, totalEffective / totalActual))
    }
    
    // MARK: - Streaks
    
    /// Current consecutive-day streak (days with adherence > threshold)
    static func currentStreak(from logs: [DayLog], threshold: Double = 0.5) -> Int {
        let calendar = Calendar.current
        let sorted = logs.sorted { $0.date > $1.date }
        var streak = 0
        var expectedDate = calendar.startOfDay(for: Date())
        
        for log in sorted {
            let logDay = calendar.startOfDay(for: log.date)
            
            // Check if this log is for the expected day
            if calendar.isDate(logDay, inSameDayAs: expectedDate) ||
               calendar.isDate(logDay, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: expectedDate)!) {
                if log.adherence >= threshold {
                    streak += 1
                    expectedDate = calendar.date(byAdding: .day, value: -1, to: logDay)!
                } else {
                    break
                }
            } else {
                break  // Gap in days
            }
        }
        
        return streak
    }
    
    // MARK: - Helpers
    
    /// Format seconds as "Xh Ym"
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(m)m"
    }
}
