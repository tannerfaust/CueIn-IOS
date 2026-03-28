//
//  SurgeDetailView.swift
//  CueIn
//
//  Surge detail, analytics, and editor.
//

import SwiftUI

struct SurgeDetailView: View {
    let surge: Surge
    let logs: [DayLog]
    let onEdit: (Surge) -> Void
    let onDelete: (Surge) -> Void

    @State private var selectedMetric: SurgeTrendMetric = .fulfillment
    @Environment(\.dismiss) private var dismiss

    private var snapshot: SurgeProgressSnapshot {
        StatsEngine.surgeProgress(for: surge, logs: logs)
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter
    }

    private var metricColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 140), spacing: Theme.spacingSM)]
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    headerCard
                    metricGrid
                    trendSection
                    focusCategorySection
                    dayBreakdownSection
                }
                .padding(.horizontal, Theme.spacingMD)
                .padding(.bottom, Theme.spacingXL)
            }
        }
        .navigationTitle("Surge")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }

            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    onEdit(surge)
                } label: {
                    Image(systemName: "pencil")
                }

                Button(role: .destructive) {
                    onDelete(surge)
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
    }

    private var headerCard: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                HStack(alignment: .top, spacing: Theme.spacingSM) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(surge.title)
                            .font(Theme.heading2())
                            .foregroundColor(Theme.textPrimary)

                        Text(surge.objective.isEmpty ? "No objective yet." : surge.objective)
                            .font(Theme.body2())
                            .foregroundColor(Theme.textSecondary)
                    }

                    Spacer(minLength: Theme.spacingSM)

                    surgeStatusTag
                }

                HStack(spacing: Theme.spacingSM) {
                    detailPill(title: "Window", value: "\(dateFormatter.string(from: surge.startDate)) - \(dateFormatter.string(from: surge.endDate))")
                    detailPill(title: "Length", value: "\(surge.durationDays) days")
                }

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    HStack {
                        Text("TIME THROUGH SURGE")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)

                        Spacer()

                        Text("\(snapshot.elapsedDays)/\(snapshot.totalDays) days")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                    }

                    CueProgressBar(
                        progress: snapshot.timeProgressRatio,
                        height: 6,
                        showLabel: false
                    )
                }
            }
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: metricColumns, spacing: Theme.spacingSM) {
            metricCard(
                title: "Fulfillment",
                value: "\(Int((snapshot.fulfillmentRatio * 100).rounded()))%",
                detail: "\(StatsEngine.formatDuration(snapshot.effectiveFocusDuration)) effective"
            )
            metricCard(
                title: "Commitment",
                value: "\(Int((snapshot.commitmentRatio * 100).rounded()))%",
                detail: "Weighted from rated focus blocks"
            )
            metricCard(
                title: "On-target days",
                value: "\(Int((snapshot.onTargetRatio * 100).rounded()))%",
                detail: "Days that cleared 80% of plan"
            )
            metricCard(
                title: "Planned focus",
                value: StatsEngine.formatDuration(snapshot.plannedFocusDuration),
                detail: "Total focused minutes planned"
            )
        }
    }

    private var trendSection: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                HStack {
                    Text("Progress Graph")
                        .font(Theme.body1())
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)

                    Spacer()
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.spacingSM) {
                        ForEach(SurgeTrendMetric.allCases) { metric in
                            Button {
                                selectedMetric = metric
                            } label: {
                                Text(metric.title)
                                    .font(Theme.caption())
                                    .fontWeight(.medium)
                                    .foregroundColor(selectedMetric == metric ? Theme.selectionForeground : Theme.textSecondary)
                                    .padding(.horizontal, Theme.spacingMD)
                                    .padding(.vertical, Theme.spacingSM)
                                    .background(selectedMetric == metric ? Theme.selectionBackground : Theme.backgroundSecondary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                SurgeTrendChartView(
                    points: snapshot.dayProgress,
                    metric: selectedMetric
                )
            }
        }
    }

    private var focusCategorySection: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Text("Focus Categories")
                    .font(Theme.body1())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Text("While this surge is active, new blocks and added tasks in these categories default to high priority.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.spacingSM) {
                        ForEach(surge.normalizedFocusCategories) { category in
                            CueChip(
                                label: category.displayName,
                                color: category.color,
                                icon: category.icon
                            )
                        }
                    }
                }
            }
        }
    }

    private var dayBreakdownSection: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Text("Day Breakdown")
                    .font(Theme.body1())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                if snapshot.dayProgress.isEmpty {
                    Text("This surge has not started yet, so there is no history to chart.")
                        .font(Theme.body2())
                        .foregroundColor(Theme.textSecondary)
                } else {
                    ForEach(snapshot.dayProgress.reversed()) { point in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(dateFormatter.string(from: point.date))
                                    .font(Theme.caption())
                                    .foregroundColor(Theme.textSecondary)

                                Spacer()

                                Text("\(Int((point.fulfillmentRatio * 100).rounded()))% fulfill • \(Int((point.commitmentRatio * 100).rounded()))% commit")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(Theme.textTertiary)
                            }

                            Text("\(StatsEngine.formatDuration(point.effectiveFocusDuration)) effective from \(StatsEngine.formatDuration(point.plannedFocusDuration)) planned")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textTertiary)

                            if point.wasOnTarget {
                                Text("On target")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(Theme.success)
                            }
                        }
                        .padding(.vertical, Theme.spacingXS)

                        if point.id != snapshot.dayProgress.first?.id {
                            Divider()
                                .background(Theme.divider)
                        }
                    }
                }
            }
        }
    }

    private var surgeStatusTag: some View {
        let isFinished = surge.isFinished()
        let isActive = surge.isActive()
        let label = isFinished ? "ENDED" : (isActive ? "LIVE" : "UPCOMING")
        let color = isFinished ? Theme.textSecondary : (isActive ? Theme.success : Theme.info)

        return Text(label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, Theme.spacingSM)
            .padding(.vertical, 5)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    private func detailPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textTertiary)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .padding(Theme.spacingSM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }

    private func metricCard(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textTertiary)

            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(detail)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.spacingMD)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .stroke(Theme.surfaceStroke, lineWidth: 1)
        )
    }
}

private enum SurgeTrendMetric: String, CaseIterable, Identifiable {
    case fulfillment
    case commitment
    case effectiveTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fulfillment: return "Fulfillment"
        case .commitment: return "Commitment"
        case .effectiveTime: return "Effective Time"
        }
    }
}

private struct SurgeTrendChartView: View {
    let points: [SurgeDayProgress]
    let metric: SurgeTrendMetric

    private var recentPoints: [SurgeDayProgress] {
        Array(points.suffix(21))
    }

    private var maxValue: Double {
        switch metric {
        case .fulfillment:
            return max(1, recentPoints.map(\.fulfillmentRatio).max() ?? 1)
        case .commitment:
            return 1
        case .effectiveTime:
            return max(1, recentPoints.map(\.effectiveFocusDuration).max() ?? 1)
        }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }

    var body: some View {
        if recentPoints.isEmpty {
            Text("No tracked days yet.")
                .font(Theme.body2())
                .foregroundColor(Theme.textSecondary)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(recentPoints) { point in
                        VStack(spacing: 6) {
                            Text(valueLabel(for: point))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Theme.textTertiary)
                                .frame(width: 28)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            RoundedRectangle(cornerRadius: 5)
                                .fill(barColor(for: point))
                                .frame(width: 18, height: barHeight(for: point))

                            Text(dateFormatter.string(from: point.date))
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                }
                .frame(height: 130, alignment: .bottom)
                .padding(.top, Theme.spacingSM)
            }
        }
    }

    private func barHeight(for point: SurgeDayProgress) -> CGFloat {
        let value = metricValue(for: point)
        let ratio = maxValue > 0 ? value / maxValue : 0
        return max(8, CGFloat(ratio) * 82)
    }

    private func metricValue(for point: SurgeDayProgress) -> Double {
        switch metric {
        case .fulfillment:
            return point.fulfillmentRatio
        case .commitment:
            return point.commitmentRatio
        case .effectiveTime:
            return point.effectiveFocusDuration
        }
    }

    private func valueLabel(for point: SurgeDayProgress) -> String {
        switch metric {
        case .fulfillment:
            return "\(Int((point.fulfillmentRatio * 100).rounded()))%"
        case .commitment:
            return "\(Int((point.commitmentRatio * 100).rounded()))%"
        case .effectiveTime:
            return StatsEngine.formatDuration(point.effectiveFocusDuration)
        }
    }

    private func barColor(for point: SurgeDayProgress) -> LinearGradient {
        let value = metricValue(for: point)
        let normalized = maxValue > 0 ? value / maxValue : 0
        let color: Color
        if normalized >= 0.75 {
            color = Theme.success
        } else if normalized >= 0.45 {
            color = Theme.warning
        } else {
            color = Theme.error
        }

        return LinearGradient(
            colors: [color.opacity(0.45), color],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

struct SurgeEditorView: View {
    private let editingSurge: Surge?
    let onSave: (Surge) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var objective: String
    @State private var startDate: Date
    @State private var durationDays: Int
    @State private var selectedCategories: Set<BlockCategory>

    init(surge: Surge?, onSave: @escaping (Surge) -> Void) {
        self.editingSurge = surge
        self.onSave = onSave
        _title = State(initialValue: surge?.title ?? "")
        _objective = State(initialValue: surge?.objective ?? "")
        _startDate = State(initialValue: surge?.startDate ?? Date())
        _durationDays = State(initialValue: max(1, surge?.durationDays ?? 30))
        _selectedCategories = State(initialValue: Set(surge?.focusCategories ?? [.work]))
    }

    private var endDate: Date {
        Calendar.current.date(byAdding: .day, value: durationDays - 1, to: Calendar.current.startOfDay(for: startDate)) ?? startDate
    }

    var body: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    Text(editingSurge == nil ? "New Surge" : "Edit Surge")
                        .font(Theme.heading2())
                        .foregroundColor(Theme.textPrimary)
                        .padding(.top, Theme.spacingLG)

                    inputSection(title: "TITLE") {
                        TextField("Name this push", text: $title)
                            .font(Theme.body1())
                            .foregroundColor(Theme.textPrimary)
                            .padding(Theme.spacingMD)
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                    }

                    inputSection(title: "OBJECTIVE") {
                        TextEditor(text: $objective)
                            .font(Theme.body2())
                            .foregroundColor(Theme.textPrimary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                            .padding(Theme.spacingSM)
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                    }

                    inputSection(title: "START DATE") {
                        DatePicker(
                            "Start",
                            selection: $startDate,
                            displayedComponents: .date
                        )
                        .datePickerStyle(.graphical)
                        .padding(Theme.spacingSM)
                        .background(Theme.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                    }

                    inputSection(title: "DURATION") {
                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.spacingSM) {
                                    ForEach([7, 14, 21, 30, 45, 60, 90], id: \.self) { option in
                                        Button {
                                            durationDays = option
                                        } label: {
                                            Text("\(option)d")
                                                .font(Theme.caption())
                                                .fontWeight(.medium)
                                                .foregroundColor(durationDays == option ? Theme.selectionForeground : Theme.textSecondary)
                                                .padding(.horizontal, Theme.spacingMD)
                                                .padding(.vertical, Theme.spacingSM)
                                                .background(durationDays == option ? Theme.selectionBackground : Theme.backgroundCard)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            Stepper(value: $durationDays, in: 3...180) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(durationDays) days")
                                        .font(Theme.body1())
                                        .fontWeight(.medium)
                                        .foregroundColor(Theme.textPrimary)
                                    Text("Ends \(formattedDate(endDate))")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                            .padding(Theme.spacingMD)
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                        }
                    }

                    inputSection(title: "FOCUS CATEGORIES") {
                        Text("Active surge categories default to high priority when you add blocks or tasks.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: Theme.spacingSM)], spacing: Theme.spacingSM) {
                            ForEach(BlockCategory.allCases) { category in
                                Button {
                                    toggle(category)
                                } label: {
                                    HStack(spacing: Theme.spacingSM) {
                                        Image(systemName: category.icon)
                                            .font(.system(size: 12, weight: .semibold))
                                        Text(category.displayName)
                                            .font(Theme.caption())
                                            .fontWeight(.medium)
                                            .lineLimit(1)
                                        Spacer()
                                    }
                                    .padding(Theme.spacingMD)
                                    .foregroundColor(selectedCategories.contains(category) ? Theme.selectionForeground : Theme.textSecondary)
                                    .background(selectedCategories.contains(category) ? category.color : Theme.backgroundCard)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    CueButton(title: editingSurge == nil ? "Create Surge" : "Save Surge", icon: "bolt.fill") {
                        let surge = Surge(
                            id: editingSurge?.id ?? UUID(),
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            objective: objective.trimmingCharacters(in: .whitespacesAndNewlines),
                            focusCategories: Array(selectedCategories).sorted { $0.rawValue < $1.rawValue },
                            startDate: Calendar.current.startOfDay(for: startDate),
                            endDate: endDate,
                            createdAt: editingSurge?.createdAt ?? Date()
                        )
                        onSave(surge)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategories.isEmpty)
                    .opacity(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedCategories.isEmpty ? 0.5 : 1)
                }
                .padding(.horizontal, Theme.spacingMD)
                .padding(.bottom, Theme.spacingXL)
            }
        }
    }

    private func inputSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text(title)
                .font(Theme.caption())
                .foregroundColor(Theme.textTertiary)
            content()
        }
    }

    private func toggle(_ category: BlockCategory) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}
