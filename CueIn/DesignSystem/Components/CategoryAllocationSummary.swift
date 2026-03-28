//
//  CategoryAllocationSummary.swift
//  CueIn
//
//  Reusable summary of how formula time is split across categories.
//

import SwiftUI

struct CategoryAllocationSummary: View {
    let title: String
    var subtitle: String? = nil
    let allocations: [CategoryAllocation]
    var emptyText: String = "No category data yet."

    var body: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)

                    Spacer()

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                if allocations.isEmpty {
                    Text(emptyText)
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.spacingSM) {
                            ForEach(allocations) { allocation in
                                allocationCard(allocation)
                            }
                        }
                    }
                }
            }
        }
    }

    private func allocationCard(_ allocation: CategoryAllocation) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            HStack(spacing: Theme.spacingXS) {
                Circle()
                    .fill(allocation.category.color)
                    .frame(width: 8, height: 8)

                Text(allocation.category.displayName)
                    .font(Theme.caption())
                    .foregroundColor(Theme.textSecondary)
            }

            Text(formatDuration(allocation.duration))
                .font(Theme.body2())
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)

            Text(allocation.percentageLabel)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(allocation.category.color)
        }
        .padding(Theme.spacingSM)
        .frame(width: 112, alignment: .leading)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusSM)
                .stroke(allocation.category.color.opacity(0.18), lineWidth: 1)
        )
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }

        return "\(minutes)m"
    }
}

struct CategoryAllocationCompactStrip: View {
    let title: String
    let allocations: [CategoryAllocation]
    var trailingLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)

                Spacer()

                if let trailingLabel {
                    if let action {
                        Button(action: action) {
                            HStack(spacing: 4) {
                                Text(trailingLabel)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .semibold))
                            }
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Text(trailingLabel)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }

            if allocations.isEmpty {
                Text("No category data yet.")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.spacingSM) {
                        ForEach(allocations) { allocation in
                            compactChip(for: allocation)
                        }
                    }
                }
            }
        }
    }

    private func compactChip(for allocation: CategoryAllocation) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(allocation.category.color)
                .frame(width: 7, height: 7)

            Text(allocation.category.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(Theme.textSecondary)

            Text(formatDuration(allocation.duration))
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, Theme.spacingSM)
        .padding(.vertical, 6)
        .background(Theme.backgroundSecondary)
        .clipShape(Capsule())
        .overlay(
            Capsule()
                .stroke(allocation.category.color.opacity(0.18), lineWidth: 1)
        )
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60

        if hours > 0 {
            return minutes > 0 ? "\(hours)h \(minutes)m" : "\(hours)h"
        }

        return "\(minutes)m"
    }
}
