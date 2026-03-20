//
//  StatsEngine.swift
//  CueIn
//
//  Computes analytics — averages, adherence, streaks.
//

import Foundation

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
