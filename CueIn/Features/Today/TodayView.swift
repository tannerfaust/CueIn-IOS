//
//  TodayView.swift
//  CueIn
//
//  Main Today tab — persistent formula, duration control,
//  stunning progress bar, real-time labels, monitoring.
//

import SwiftUI

struct TodayView: View {
    @EnvironmentObject var dataStore: DataStore
    @StateObject var engine = FormulaEngine()
    @StateObject private var viewModel: TodayViewModel
    
    init(dataStore: DataStore) {
        let engine = FormulaEngine()
        _engine = StateObject(wrappedValue: engine)
        _viewModel = StateObject(wrappedValue: TodayViewModel(dataStore: dataStore, engine: engine))
    }
    
    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                progressSection
                
                if !viewModel.isStarted {
                    durationControl
                }
                
                viewToggle
                scheduleSection
            }
        }
        .sheet(isPresented: $viewModel.showRoadblockSheet) {
            RoadblockSheet(viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showAddTaskSheet) {
            AddTaskSheet(viewModel: viewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showChangeFormula) {
            changeFormulaSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showNewFormula) {
            NavigationView {
                FormulaEditorView(viewModel: LabViewModel(dataStore: dataStore), formula: nil)
                    .environmentObject(dataStore)
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.stageName)
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
                    .textCase(.uppercase)
                
                Text(viewModel.formulaName.isEmpty ? "No Formula" : viewModel.formulaName)
                    .font(Theme.heading2())
                    .foregroundColor(Theme.textPrimary)
            }
            
            Spacer()
            
            // Start / Roadblock Button
            if !viewModel.isStarted {
                CueButton(title: "Start", icon: "play.fill", isCompact: true) {
                    viewModel.startDay()
                }
            } else {
                CueButton(
                    title: "Roadblock",
                    icon: "exclamationmark.triangle.fill",
                    style: .secondary,
                    isCompact: true
                ) {
                    viewModel.triggerRoadblock()
                }
            }
            
            // Three-dot menu
            Menu {
                Button {
                    viewModel.showChangeFormula = true
                } label: {
                    Label("Change Formula", systemImage: "arrow.triangle.2.circlepath")
                }
                
                Button {
                    viewModel.showNewFormula = true
                } label: {
                    Label("New Formula for Today", systemImage: "plus.square")
                }
                
                Button {
                    withAnimation {
                        viewModel.showRealTime.toggle()
                    }
                } label: {
                    Label(
                        viewModel.showRealTime ? "Hide Clock Times" : "Show Clock Times",
                        systemImage: viewModel.showRealTime ? "clock.badge.xmark" : "clock"
                    )
                }
                
                if viewModel.isStarted {
                    Button(role: .destructive) {
                        viewModel.stopDay()
                    } label: {
                        Label("Stop & Save Day", systemImage: "stop.circle")
                    }
                }
                
                Button {
                    viewModel.loadTodayFormula()
                } label: {
                    Label("Reset Today", systemImage: "arrow.counterclockwise")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 36, height: 36)
                    .background(Theme.backgroundTertiary)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.top, Theme.spacingSM)
        .padding(.bottom, Theme.spacingMD)
    }
    
    // MARK: - Progress
    
    private var progressSection: some View {
        VStack(spacing: Theme.spacingXS) {
            CueProgressBar(
                progress: engine.dayProgress,
                height: 6,
                showLabel: false,
                barColor: currentCategoryColor,
                useGradient: true
            )
            
            HStack {
                Text(engine.formattedElapsed)
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
                
                Spacer()
                
                if viewModel.isStarted, let end = viewModel.runningEndTime {
                    Text("ends ~\(end)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textTertiary)
                }
                
                Text("\(engine.totalChecked)/\(engine.blocks.count) blocks")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.bottom, Theme.spacingMD)
    }
    
    private var currentCategoryColor: Color {
        guard let block = engine.currentBlock else { return .white }
        return block.categoryColor
    }
    
    // MARK: - Duration Control (pre-start)
    
    private var durationControl: some View {
        CueCard {
            VStack(spacing: Theme.spacingSM) {
                HStack {
                    Text("Today's Duration")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                    
                    Spacer()
                    
                    Text("Ends ~\(viewModel.estimatedEndTimeIfStartNow)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(Theme.textSecondary)
                }
                
                HStack {
                    Text("\(Int(engine.targetDuration / 3600))h")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 50)
                    
                    Slider(
                        value: Binding(
                            get: { engine.targetDuration / 3600 },
                            set: { viewModel.changeDuration($0) }
                        ),
                        in: 6...20,
                        step: 1
                    )
                    .tint(.white)
                }
            }
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.bottom, Theme.spacingSM)
    }
    
    // MARK: - View Toggle
    
    private var viewToggle: some View {
        HStack(spacing: 0) {
            ForEach(TodayViewModel.ViewMode.allCases, id: \.self) { mode in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.viewMode = mode
                    }
                }) {
                    Text(mode.rawValue)
                        .font(Theme.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(viewModel.viewMode == mode ? .white : Theme.textTertiary)
                        .padding(.horizontal, Theme.spacingMD)
                        .padding(.vertical, Theme.spacingSM)
                        .background(
                            viewModel.viewMode == mode
                            ? Theme.backgroundElevated
                            : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
            Spacer()
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.bottom, Theme.spacingSM)
    }
    
    // MARK: - Schedule
    
    private var scheduleSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.spacingSM) {
                    ForEach(Array(engine.blocks.enumerated()), id: \.element.id) { index, block in
                        let isActive = index == engine.currentBlockIndex && viewModel.isStarted
                        
                        if viewModel.viewMode == .focused && !isActive && viewModel.isStarted {
                            CueBlockRow(
                                block: block,
                                isActive: false,
                                onCheck: { viewModel.checkBlock(at: index) },
                                onMenu: { viewModel.removeBlock(at: index) },
                                showRealTime: viewModel.showRealTime && viewModel.isStarted,
                                realTimeLabel: viewModel.realTimeLabel(for: index)
                            )
                            .scaleEffect(0.92)
                            .opacity(0.4)
                            .blur(radius: 2)
                        } else {
                            CueBlockRow(
                                block: block,
                                isActive: isActive,
                                onCheck: { viewModel.checkBlock(at: index) },
                                onMenu: { viewModel.removeBlock(at: index) },
                                showRealTime: viewModel.showRealTime && viewModel.isStarted,
                                realTimeLabel: viewModel.realTimeLabel(for: index)
                            )
                            .id(block.id)
                        }
                    }
                    
                    if !viewModel.isStarted && !engine.blocks.isEmpty {
                        explanationCard
                    }
                }
                .padding(.horizontal, Theme.spacingMD)
                .padding(.bottom, Theme.spacingXL)
            }
            .onChange(of: engine.currentBlockIndex) { newIndex in
                if newIndex < engine.blocks.count {
                    withAnimation {
                        proxy.scrollTo(engine.blocks[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Explanation
    
    private var explanationCard: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Label("How blocks work", systemImage: "info.circle")
                    .font(Theme.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textSecondary)
                
                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    explanationRow(icon: "wind", text: "Flowing — auto-advances when time runs out")
                    explanationRow(icon: "lock.fill", text: "Blocking — stays until you check it off")
                    explanationRow(icon: "timer", text: "Early check-off gives extra time to priority blocks")
                }
            }
        }
        .padding(.top, Theme.spacingSM)
    }
    
    private func explanationRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.spacingSM) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 16)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
        }
    }
    
    // MARK: - Change Formula Sheet
    
    private var changeFormulaSheet: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                Text("Choose Formula")
                    .font(Theme.heading2())
                    .foregroundColor(Theme.textPrimary)
                    .padding(.top, Theme.spacingLG)
                
                ForEach(dataStore.formulas.filter({ $0.type == .full })) { formula in
                    Button {
                        viewModel.engine.loadFormula(formula, expandingWith: dataStore)
                        viewModel.formulaName = formula.name
                        viewModel.showChangeFormula = false
                    } label: {
                        HStack(spacing: Theme.spacingMD) {
                            Text(formula.emoji)
                                .font(.system(size: 24))
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(formula.name)
                                    .font(Theme.body1())
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.textPrimary)
                                
                                Text("\(formula.blockCount) blocks • \(formula.formattedTargetDuration)")
                                    .font(Theme.caption())
                                    .foregroundColor(Theme.textSecondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .padding(Theme.spacingMD)
                        .background(Theme.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.horizontal, Theme.spacingMD)
        }
    }
}
