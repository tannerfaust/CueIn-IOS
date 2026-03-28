//
//  ProfileView.swift
//  CueIn
//
//  Profile tab — stage, targets, surges, settings, history.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var appearanceModeRawValue: String
    @StateObject private var viewModel: ProfileViewModel
    private let engine: FormulaEngine

    @State private var editStageName: String = ""
    @State private var showSettings: Bool = false
    @State private var showHistory: Bool = false
    @State private var selectedSurge: Surge? = nil

    init(dataStore: DataStore, appearanceModeRawValue: Binding<String>, engine: FormulaEngine) {
        self.engine = engine
        _appearanceModeRawValue = appearanceModeRawValue
        _viewModel = StateObject(wrappedValue: ProfileViewModel(dataStore: dataStore))
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    header
                        .padding(.horizontal, Theme.spacingMD)
                        .padding(.top, Theme.spacingSM)

                    stageCard
                        .padding(.horizontal, Theme.spacingMD)

                    targetCard
                        .padding(.horizontal, Theme.spacingMD)

                    surgesSection
                        .padding(.horizontal, Theme.spacingMD)
                }
                .padding(.bottom, Theme.spacingXL)
            }
        }
        .sheet(isPresented: $viewModel.showSurgeEditor) {
            SurgeEditorView(surge: viewModel.editingSurge) { surge in
                viewModel.saveSurge(surge)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedSurge) { surge in
            NavigationStack {
                SurgeDetailView(
                    surge: currentSurge(for: surge),
                    logs: dataStore.dayLogs,
                    onEdit: { editing in
                        selectedSurge = nil
                        viewModel.startEditingSurge(editing)
                    },
                    onDelete: { deleting in
                        viewModel.deleteSurge(deleting)
                        selectedSurge = nil
                    }
                )
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                dataStore: dataStore,
                appearanceModeRawValue: $appearanceModeRawValue
            )
        }
        .sheet(isPresented: $showHistory) {
            ProfileHistorySheet(dataStore: dataStore, engine: engine, showHistory: $showHistory)
        }
    }

    private var header: some View {
        HStack {
            Text("Profile")
                .font(Theme.heading1())
                .foregroundColor(Theme.textPrimary)

            Spacer()

            HStack(spacing: Theme.spacingSM) {
                Button { showHistory = true } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var stageCard: some View {
        CueCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STAGE")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)

                    if viewModel.isEditingStage {
                        TextField("Stage name", text: $editStageName)
                            .font(Theme.heading2())
                            .foregroundColor(Theme.textPrimary)
                            .onSubmit { viewModel.updateStage(editStageName) }
                    } else {
                        Text(viewModel.profile.stageName)
                            .font(Theme.heading2())
                            .foregroundColor(Theme.textPrimary)
                    }
                }

                Spacer()

                Button {
                    if viewModel.isEditingStage {
                        viewModel.updateStage(editStageName)
                    } else {
                        editStageName = viewModel.profile.stageName
                        viewModel.isEditingStage = true
                    }
                } label: {
                    Image(systemName: viewModel.isEditingStage ? "checkmark.circle.fill" : "pencil.circle")
                        .font(.system(size: 22))
                        .foregroundColor(viewModel.isEditingStage ? Theme.success : Theme.textSecondary)
                }
            }
        }
    }

    private var targetCard: some View {
        CueCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAILY TARGET")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)

                    Text("\(viewModel.profile.dailyTargetHours)h / day")
                        .font(Theme.body1())
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)
                }

                Spacer()

                HStack(spacing: Theme.spacingSM) {
                    Button {
                        if viewModel.profile.dailyTargetHours > 4 {
                            viewModel.dataStore.profile.dailyTargetHours -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 22))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)

                    Text("\(viewModel.profile.dailyTargetHours)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 30)

                    Button {
                        if viewModel.profile.dailyTargetHours < 20 {
                            viewModel.dataStore.profile.dailyTargetHours += 1
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 22))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var surgesSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Surges")
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)

                    Text("Focused windows that raise priority on chosen categories and track whether you actually delivered.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }

                Spacer()

                Button {
                    viewModel.startCreatingSurge()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.onAccent)
                        .frame(width: 26, height: 26)
                        .background(Theme.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if viewModel.sortedSurges.isEmpty {
                CueCard {
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        Text("No surges yet")
                            .font(Theme.body1())
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)

                        Text("Create a 14-day, 30-day, or custom push. Your focus categories will default to high priority while the surge is active.")
                            .font(Theme.body2())
                            .foregroundColor(Theme.textSecondary)

                        CueButton(title: "Create First Surge", icon: "bolt.fill") {
                            viewModel.startCreatingSurge()
                        }
                        .padding(.top, Theme.spacingXS)
                    }
                }
            } else {
                ForEach(viewModel.sortedSurges) { surge in
                    surgeCard(surge)
                }
            }
        }
    }

    private func surgeCard(_ surge: Surge) -> some View {
        let snapshot = StatsEngine.surgeProgress(for: surge, logs: dataStore.dayLogs)

        return CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                HStack(alignment: .top, spacing: Theme.spacingSM) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: Theme.spacingSM) {
                            Text(surge.title)
                                .font(Theme.body1())
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(2)

                            statusBadge(for: surge)
                        }

                        Text(surge.objective.isEmpty ? "No objective yet." : surge.objective)
                            .font(Theme.body2())
                            .foregroundColor(Theme.textSecondary)
                            .lineLimit(3)
                    }

                    Spacer(minLength: Theme.spacingSM)

                    Menu {
                        Button {
                            selectedSurge = currentSurge(for: surge)
                        } label: {
                            Label("Open Progress", systemImage: "chart.line.uptrend.xyaxis")
                        }

                        Button {
                            viewModel.startEditingSurge(surge)
                        } label: {
                            Label("Edit Surge", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            viewModel.deleteSurge(surge)
                        } label: {
                            Label("Delete Surge", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                if !surge.focusCategories.isEmpty {
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

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    progressHeader(
                        title: "Fulfillment",
                        value: "\(Int((snapshot.fulfillmentRatio * 100).rounded()))%"
                    )

                    CueProgressBar(
                        progress: min(1, snapshot.fulfillmentRatio),
                        height: 6,
                        showLabel: false
                    )

                    Text("\(StatsEngine.formatDuration(snapshot.effectiveFocusDuration)) delivered against \(StatsEngine.formatDuration(snapshot.plannedFocusDuration)) planned")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }

                HStack(spacing: Theme.spacingSM) {
                    compactMetric(
                        title: "Commitment",
                        value: "\(Int((snapshot.commitmentRatio * 100).rounded()))%"
                    )
                    compactMetric(
                        title: "On-target days",
                        value: "\(Int((snapshot.onTargetRatio * 100).rounded()))%"
                    )
                    compactMetric(
                        title: surge.isFinished() ? "Length" : "Days left",
                        value: surge.isFinished() ? "\(surge.durationDays)d" : "\(snapshot.remainingDays)d"
                    )
                }

                Button {
                    selectedSurge = currentSurge(for: surge)
                } label: {
                    HStack(spacing: Theme.spacingSM) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Open Progress")
                            .font(Theme.caption())
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(Theme.accent)
                    .padding(.horizontal, Theme.spacingMD)
                    .padding(.vertical, Theme.spacingSM)
                    .background(Theme.backgroundSecondary)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .onTapGesture {
            selectedSurge = currentSurge(for: surge)
        }
    }

    private func progressHeader(title: String, value: String) -> some View {
        HStack {
            Text(title.uppercased())
                .font(Theme.caption())
                .foregroundColor(Theme.textTertiary)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private func compactMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacingSM)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }

    private func statusBadge(for surge: Surge) -> some View {
        let palette = surgeStatusPalette(for: surge)

        return Text(palette.label)
            .font(.system(size: 10, weight: .bold))
            .foregroundColor(palette.foreground)
            .padding(.horizontal, Theme.spacingSM)
            .padding(.vertical, 5)
            .background(palette.background)
            .clipShape(Capsule())
    }

    private func surgeStatusPalette(for surge: Surge) -> (label: String, foreground: Color, background: Color) {
        if surge.isFinished() {
            return ("ENDED", Theme.textSecondary, Theme.backgroundSecondary)
        }
        if surge.isActive() {
            return ("LIVE", Theme.success, Theme.success.opacity(0.14))
        }
        return ("UPCOMING", Theme.info, Theme.info.opacity(0.14))
    }

    private func currentSurge(for surge: Surge) -> Surge {
        viewModel.profile.surges.first(where: { $0.id == surge.id }) ?? surge
    }
}

private struct ProfileHistorySheet: View {
    let dataStore: DataStore
    let engine: FormulaEngine
    @Binding var showHistory: Bool
    @StateObject private var viewModel: MonitorViewModel

    init(dataStore: DataStore, engine: FormulaEngine, showHistory: Binding<Bool>) {
        self.dataStore = dataStore
        self.engine = engine
        _showHistory = showHistory
        _viewModel = StateObject(wrappedValue: MonitorViewModel(dataStore: dataStore, engine: engine))
    }

    var body: some View {
        NavigationView {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()
                HistoryView(viewModel: viewModel)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showHistory = false
                    }
                }
            }
        }
    }
}
