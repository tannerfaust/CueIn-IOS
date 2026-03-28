//
//  TodayView.swift
//  CueIn
//
//  Main Today tab — persistent formula, duration control,
//  stunning progress bar, real-time labels, monitoring.
//

import SwiftUI
import UniformTypeIdentifiers

struct TodayView: View {
    @EnvironmentObject var dataStore: DataStore
    @ObservedObject var engine: FormulaEngine
    @AppStorage(TodayProgressDisplayMode.storageKey) private var todayProgressDisplayModeRawValue = TodayProgressDisplayMode.elapsed.rawValue
    @AppStorage(CommitmentRatingSetting.storageKey) private var isCommitmentRatingEnabled = CommitmentRatingSetting.defaultValue
    @AppStorage(ExecutionControlsSetting.storageKey) private var isExecutionControlsEnabled = ExecutionControlsSetting.defaultValue
    @AppStorage(LazyStartSetting.enabledStorageKey) private var isLazyStartEnabled = LazyStartSetting.defaultEnabled
    @AppStorage(LazyStartSetting.thresholdStorageKey) private var lazyStartThresholdSeconds = LazyStartSetting.defaultThresholdSeconds
    @StateObject private var viewModel: TodayViewModel
    @Namespace private var focusedBlockNamespace
    @State private var showTodaySplitSheet: Bool = false
    @State private var showTodayFormulaWorkshop: Bool = false
    @State private var draggedTodayBlock: Block? = nil
    @State private var showEditBlockSheet: Bool = false
    @State private var showCommitmentRatingSheet: Bool = false
    @State private var showLazyStartSheet: Bool = false
    @State private var editingBlockID: UUID? = nil
    @State private var commitmentBlockID: UUID? = nil
    @State private var editBlockName: String = ""
    @State private var draftCommitmentRating: Int = 5
    @State private var lazyStartEndTime: Date = Date()
    @State private var editBlockDuration: Double = 30
    @State private var editBlockCategory: BlockCategory = .custom
    @State private var editBlockSubcategory: String = ""
    @State private var editBlockFlowLogic: FlowLogic = .flowing
    @State private var editBlockPriority: BlockPriority = .medium
    @State private var editBlockHasFixedStartTime: Bool = false
    @State private var editBlockFixedStartTime: Date = Date()
    @State private var editBlockFixTimeframeToo: Bool = false
    @State private var showNewTodaySubcategory: Bool = false
    @State private var newTodaySubcategoryName: String = ""
    @State private var isTemporarilyExpanded: Bool = false
    @State private var focusResetTask: DispatchWorkItem? = nil
    
    init(dataStore: DataStore, engine: FormulaEngine) {
        self.engine = engine
        _viewModel = StateObject(wrappedValue: TodayViewModel(dataStore: dataStore, engine: engine))
    }
    
    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                headerSection
                progressSection
                topUtilityButtons
                
                if !viewModel.isStarted {
                    durationControl
                }

                scheduleSection
            }
        }
        .sheet(isPresented: $viewModel.showRoadblockSheet) {
            RoadblockSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
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
        .sheet(isPresented: $showTodayFormulaWorkshop) {
            TodayFormulaWorkshopView(viewModel: viewModel)
                .environmentObject(dataStore)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showTodaySplitSheet) {
            todaySplitSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showEditBlockSheet) {
            editBlockSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showCommitmentRatingSheet) {
            commitmentRatingSheet
                .presentationDetents([.fraction(0.34), .medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showLazyStartSheet) {
            lazyStartSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            if !isExecutionControlsEnabled && engine.isExecutionModeEnabled {
                viewModel.setExecutionModeEnabled(false)
            }
        }
        .onChange(of: isExecutionControlsEnabled) { isEnabled in
            if !isEnabled && engine.isExecutionModeEnabled {
                viewModel.setExecutionModeEnabled(false)
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
                    handleStartTapped()
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
                    showTodayFormulaWorkshop = true
                } label: {
                    Label("Today Formula Workshop", systemImage: "slider.horizontal.3")
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

                if viewModel.supportsTodayTimeMagnet {
                    Button {
                        viewModel.toggleTodayTimeMagnet()
                    } label: {
                        Label(
                            engine.timeMagnet.isEnabled ? "Turn Time Magnet Off" : "Turn Time Magnet On",
                            systemImage: engine.timeMagnet.isEnabled ? "bolt.slash" : "bolt.badge.clock"
                        )
                    }
                }
                
                if viewModel.isStarted {
                    Button(role: .destructive) {
                        viewModel.stopDay()
                    } label: {
                        Label("Stop & Save Day", systemImage: "stop.circle")
                    }
                }
                
                Button {
                    viewModel.resetToday()
                } label: {
                    Label("Reset Today", systemImage: "arrow.counterclockwise")
                }

                Button(role: .destructive) {
                    viewModel.clearToday()
                } label: {
                    Label("Clear Today", systemImage: "trash")
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
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayPercentageSummary)
                        .font(Theme.caption())
                        .foregroundColor(Theme.textSecondary)

                    Text(donePercentageSummary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    if viewModel.isStarted, let end = viewModel.runningEndTime {
                        Text("ends ~\(end)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textTertiary)
                    }

                    Text(blockCountSummary)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.bottom, Theme.spacingMD)
    }

    private var todayProgressDisplayMode: TodayProgressDisplayMode {
        TodayProgressDisplayMode(rawValue: todayProgressDisplayModeRawValue) ?? .elapsed
    }

    private var dayPercentageSummary: String {
        switch todayProgressDisplayMode {
        case .elapsed:
            return "\(engine.formattedElapsed) passed • \(engine.dayProgressPercentageLabel)"
        case .remaining:
            return "\(engine.formattedRemaining) left • \(engine.remainingDayPercentageLabel)"
        }
    }

    private var donePercentageSummary: String {
        "Done \(engine.completedPlannedDayPercentageLabel) of planned day"
    }

    private var blockCountSummary: String {
        "\(engine.totalChecked)/\(engine.blocks.count) blocks"
    }
    
    private var currentCategoryColor: Color {
        guard let block = engine.currentBlock else { return Theme.accent }
        return block.categoryColor
    }

    private var todayBlockDurationRange: ClosedRange<Double> {
        5...max(240, engine.targetDuration / 60)
    }

    private var lazyStartThresholdDate: Date {
        Calendar.current.startOfDay(for: Date()).addingTimeInterval(lazyStartThresholdSeconds)
    }

    private var shouldPromptForLazyStart: Bool {
        !viewModel.isStarted && isLazyStartEnabled && Date() >= lazyStartThresholdDate
    }

    private var resolvedLazyStartEndTime: Date {
        let now = Date()
        let calendar = Calendar.current
        let chosenComponents = calendar.dateComponents([.hour, .minute], from: lazyStartEndTime)
        let nowComponents = calendar.dateComponents([.year, .month, .day], from: now)

        guard let sameDay = calendar.date(from: DateComponents(
            year: nowComponents.year,
            month: nowComponents.month,
            day: nowComponents.day,
            hour: chosenComponents.hour,
            minute: chosenComponents.minute
        )) else {
            return now.addingTimeInterval(engine.targetDuration)
        }

        if sameDay > now {
            return sameDay
        }

        return calendar.date(byAdding: .day, value: 1, to: sameDay) ?? sameDay.addingTimeInterval(24 * 3600)
    }

    private var lazyStartPreviewDuration: TimeInterval {
        max(30 * 60, resolvedLazyStartEndTime.timeIntervalSince(Date()))
    }

    private var lazyStartPreviewLabel: String {
        StatsEngine.formatDuration(lazyStartPreviewDuration)
    }

    private var usesCompactLazyStartLayout: Bool {
        UIScreen.main.bounds.height <= 700
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
                        .foregroundColor(Theme.accent)
                        .frame(width: 50)
                    
                    Slider(
                        value: Binding(
                            get: { engine.targetDuration / 3600 },
                            set: { viewModel.changeDuration($0) }
                        ),
                        in: 4...max(4, engine.durationCeiling / 3600),
                        step: 1
                    )
                    .tint(Theme.accent)
                }

                Text("Today can be shortened before start, but it cannot be stretched past the formula unless you deliberately edit the formula or block durations.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.horizontal, Theme.spacingMD)
        .padding(.bottom, Theme.spacingSM)
    }
    
    @ViewBuilder
    private var topUtilityButtons: some View {
        if !engine.blocks.isEmpty {
            HStack {
                if isExecutionControlsEnabled {
                    Button {
                        viewModel.toggleExecutionMode()
                    } label: {
                        Image(systemName: engine.isExecutionModeEnabled ? "play.circle.fill" : "play.circle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(engine.isExecutionModeEnabled ? .black : Theme.textSecondary)
                            .frame(width: 38, height: 38)
                            .background(engine.isExecutionModeEnabled ? currentCategoryColor : Theme.backgroundCard)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                todaySplitButton
            }
            .padding(.horizontal, Theme.spacingMD)
            .padding(.bottom, Theme.spacingSM)
        }
    }

    private var todaySplitButton: some View {
        Button {
            showTodaySplitSheet = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)

                Text("Split")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)

                Text(StatsEngine.formatDuration(engine.blocks.reduce(0) { $0 + $1.duration }))
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.textPrimary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Theme.backgroundCard)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var todaySplitSheet: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                Text("Today's Split")
                    .font(Theme.heading2())
                    .foregroundColor(Theme.textPrimary)

                CategoryAllocationSummary(
                    title: "CATEGORY SPLIT",
                    subtitle: StatsEngine.formatDuration(engine.blocks.reduce(0) { $0 + $1.duration }),
                    allocations: engine.blocks.categoryAllocations(),
                    emptyText: "Load a formula to see the category mix for today."
                )

                Spacer()
            }
            .padding(Theme.spacingMD)
        }
    }
    
    // MARK: - Schedule
    
    private var scheduleSection: some View {
        GeometryReader { _ in
            ScrollViewReader { proxy in
                ZStack {
                    ScrollView {
                        LazyVStack(spacing: Theme.spacingSM) {
                            ForEach(engine.blocks) { block in
                                if let index = viewModel.blockIndex(for: block.id) {
                                    let isActive = index == engine.currentBlockIndex && viewModel.isStarted

                                    todayBlockRow(block: block, index: index, isActive: isActive)
                                        .id(block.id)
                                        .onDrop(
                                            of: [UTType.text],
                                            delegate: TodayBlockDropDelegate(
                                                item: block,
                                                blocks: $engine.blocks,
                                                draggedBlock: $draggedTodayBlock,
                                                onReorder: { from, to in
                                                    viewModel.moveBlock(fromOffsets: from, toOffset: to)
                                                }
                                            )
                                        )
                                }
                            }

                            Color.clear
                                .frame(height: 12)
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: TodayBlockEndDropDelegate(
                                        blocks: $engine.blocks,
                                        draggedBlock: $draggedTodayBlock,
                                        onReorderToEnd: {
                                            guard let draggedTodayBlock,
                                                  let fromIndex = viewModel.blockIndex(for: draggedTodayBlock.id) else { return }
                                            viewModel.moveBlock(
                                                fromOffsets: IndexSet(integer: fromIndex),
                                                toOffset: engine.blocks.count
                                            )
                                        }
                                    )
                                )

                            if !viewModel.isStarted && !engine.blocks.isEmpty {
                                explanationCard
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)
                        .padding(.bottom, Theme.spacingXL)
                        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: engine.blocks.map(\.id))
                    }
                    .simultaneousGesture(
                        TapGesture().onEnded {
                            registerScheduleInteraction()
                        }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 1).onChanged { _ in
                            registerScheduleInteraction()
                        }
                    )

                    if let focused = focusedBlockContext {
                        centeredFocusedBlockOverlay(
                            block: focused.block,
                            index: focused.index,
                            isActive: focused.isActive
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .onChange(of: engine.currentBlockIndex) { newIndex in
                    if newIndex < engine.blocks.count {
                        withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                            proxy.scrollTo(engine.blocks[newIndex].id, anchor: .center)
                        }
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

    private func todayBlockRow(block: Block, index: Int, isActive: Bool) -> some View {
        let isExecuting = engine.executingBlockID == block.id
        let isPrimaryFocus = index == focusAnchorIndex || isExecuting
        let isLiftedToFocusOverlay = usesFocusedPresentation && isPrimaryFocus

        return todayBlockContent(block: block, index: index, isActive: isActive)
        .matchedGeometryEffect(id: block.id, in: focusedBlockNamespace)
        .opacity(
            isLiftedToFocusOverlay
            ? 0.001
            : (usesFocusedPresentation && !isPrimaryFocus ? 0.32 : 1)
        )
        .scaleEffect(
            draggedTodayBlock?.id == block.id
            ? 0.985
            : (usesFocusedPresentation && !isPrimaryFocus ? 0.93 : 1)
        )
        .blur(radius: isLiftedToFocusOverlay ? 0 : (usesFocusedPresentation && !isPrimaryFocus ? 8 : 0))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .stroke(
                    draggedTodayBlock?.id == block.id || isExecuting ? block.categoryColor.opacity(isExecuting ? 0.28 : 0.35) : Color.clear,
                    lineWidth: 1
                )
        )
        .allowsHitTesting(!isLiftedToFocusOverlay)
        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.86), value: draggedTodayBlock?.id == block.id || isExecuting || usesFocusedPresentation)
    }

    private func todayBlockContent(block: Block, index: Int, isActive: Bool) -> some View {
        let isExecuting = isExecutionControlsEnabled && engine.executingBlockID == block.id
        let isAwaitingExecution = isExecutionControlsEnabled && engine.isExecutionModeEnabled && !isExecuting && !block.isChecked
        let canShowPlay = isExecutionControlsEnabled
            && engine.isExecutionModeEnabled
            && engine.executingBlockID == nil
            && !block.isChecked
            && index >= engine.currentBlockIndex

        return VStack(alignment: .leading, spacing: Theme.spacingSM) {
            CueBlockRow(
                block: block,
                isActive: isActive,
                isExecuting: isExecuting,
                isAwaitingExecution: isAwaitingExecution,
                isPaused: isActive && engine.isCurrentBlockPaused,
                onCheck: {
                    registerScheduleInteraction()
                    viewModel.toggleBlockCheck(at: index)
                },
                onExecutionPlay: canShowPlay ? {
                    registerScheduleInteraction()
                    viewModel.startExecutingBlock(at: index)
                } : nil,
                onPlayNow: !block.isChecked ? {
                    registerScheduleInteraction()
                    viewModel.playBlockNow(withId: block.id)
                } : nil,
                onCommitmentTap: isCommitmentRatingEnabled && block.isChecked ? {
                    registerScheduleInteraction()
                    prepareCommitmentRating(for: block.id)
                } : nil,
                onPauseToggle: isExecutionControlsEnabled && isActive && viewModel.isStarted && !block.isChecked ? {
                    registerScheduleInteraction()
                    viewModel.toggleCurrentBlockPause()
                } : nil,
                onEdit: {
                    registerScheduleInteraction()
                    prepareTodayBlockEditor(for: block.id)
                },
                onDuplicate: {
                    registerScheduleInteraction()
                    viewModel.duplicateBlock(withId: block.id)
                },
                onDelete: {
                    registerScheduleInteraction()
                    viewModel.removeBlock(withId: block.id)
                },
                dragItemProvider: {
                    registerScheduleInteraction()
                    draggedTodayBlock = block
                    return NSItemProvider(object: block.id.uuidString as NSString)
                },
                showRealTime: block.hasFixedStartTime || (viewModel.showRealTime && viewModel.isStarted),
                realTimeLabel: viewModel.realTimeLabel(for: index),
                showCommitmentButton: isCommitmentRatingEnabled
            )

            if isExecutionControlsEnabled && isExecuting {
                executionControls(for: block)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if isActive,
               let miniBlocks = block.miniBlocks,
               !miniBlocks.isEmpty {
                activeMiniFormulaList(
                    miniBlocks: miniBlocks,
                    parentBlockIndex: index,
                    accentColor: block.categoryColor
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private func executionControls(for block: Block) -> some View {
        HStack(spacing: Theme.spacingSM) {
            Button {
                viewModel.toggleCurrentBlockPause()
            } label: {
                Text(engine.isCurrentBlockPaused ? "Resume" : "Pause")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.backgroundCard)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                viewModel.stopExecutingBlock()
            } label: {
                Text("Stop")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.backgroundCard)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 2)
    }

    private func centeredFocusedBlockOverlay(block: Block, index: Int, isActive: Bool) -> some View {
        ZStack {
            Circle()
                .fill(block.categoryColor.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 56)
                .scaleEffect(usesFocusedPresentation ? 1 : 0.92)

            todayBlockContent(block: block, index: index, isActive: isActive)
                .matchedGeometryEffect(id: block.id, in: focusedBlockNamespace)
                .shadow(color: block.categoryColor.opacity(0.2), radius: 24, x: 0, y: 12)
        }
        .padding(.horizontal, Theme.spacingMD)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .offset(y: -34)
        .transition(.opacity)
        .zIndex(10)
        .animation(.spring(response: 0.46, dampingFraction: 0.86), value: block.id)
    }

    private var focusAnchorIndex: Int {
        if let executingIndex = engine.executingBlockIndex {
            return executingIndex
        }

        guard !engine.blocks.isEmpty else { return 0 }
        return min(max(engine.currentBlockIndex, 0), engine.blocks.count - 1)
    }

    private var usesFocusedPresentation: Bool {
        viewModel.isStarted && !isTemporarilyExpanded && engine.blocks.count > 1
    }

    private var focusedBlockContext: (block: Block, index: Int, isActive: Bool)? {
        guard usesFocusedPresentation else { return nil }
        guard engine.blocks.indices.contains(focusAnchorIndex) else { return nil }

        let block = engine.blocks[focusAnchorIndex]
        return (block, focusAnchorIndex, focusAnchorIndex == engine.currentBlockIndex)
    }

    private func registerScheduleInteraction() {
        focusResetTask?.cancel()

        if !isTemporarilyExpanded {
            withAnimation(.easeInOut(duration: 0.2)) {
                isTemporarilyExpanded = true
            }
        }

        let workItem = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.35)) {
                isTemporarilyExpanded = false
            }
        }

        focusResetTask = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: workItem)
    }

    private func activeMiniFormulaList(
        miniBlocks: [Block],
        parentBlockIndex: Int,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack {
                Label("Mini-Formula", systemImage: "square.stack.3d.up")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textSecondary)

                Spacer()

                Text("\(miniBlocks.filter(\.isChecked).count)/\(miniBlocks.count) done")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
            }

            ForEach(Array(miniBlocks.enumerated()), id: \.element.id) { miniIndex, miniBlock in
                Button {
                    viewModel.checkMiniBlock(at: parentBlockIndex, miniTaskIndex: miniIndex)
                } label: {
                    HStack(spacing: Theme.spacingSM) {
                        ZStack {
                            Circle()
                                .stroke(miniBlock.isChecked ? Theme.success : Theme.textTertiary, lineWidth: 1.25)
                                .frame(width: 18, height: 18)

                            if miniBlock.isChecked {
                                Circle()
                                    .fill(Theme.success)
                                    .frame(width: 18, height: 18)

                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.black)
                            }
                        }

                        RoundedRectangle(cornerRadius: 2)
                            .fill(miniBlock.categoryColor)
                            .frame(width: 3, height: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(miniBlock.name)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(miniBlock.isChecked ? Theme.textTertiary : Theme.textPrimary)
                                .strikethrough(miniBlock.isChecked)

                            HStack(spacing: Theme.spacingSM) {
                                Text(miniBlock.formattedDuration)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(Theme.textTertiary)

                                if !miniBlock.subcategory.isEmpty {
                                    Text(miniBlock.subcategory)
                                        .font(.system(size: 10))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                        }

                        Spacer()
                    }
                    .padding(.vertical, Theme.spacingXS)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.spacingMD)
        .background(Theme.backgroundCard)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .stroke(accentColor.opacity(0.15), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
        .padding(.leading, Theme.spacingLG)
    }

    private var editBlockSheet: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingMD) {
                    Text("Edit Block")
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)
                        .padding(.top, Theme.spacingLG)

                    TextField("Block name", text: $editBlockName)
                        .font(Theme.body1())
                        .foregroundColor(Theme.textPrimary)
                        .padding(Theme.spacingMD)
                        .background(Theme.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))

                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("DURATION")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)

                        HStack {
                            Text("\(Int(editBlockDuration))m")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.accent)
                                .frame(width: 55)

                            Slider(value: $editBlockDuration, in: todayBlockDurationRange, step: 5)
                                .tint(Theme.accent)
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("CATEGORY")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.spacingSM) {
                                ForEach(BlockCategory.allCases) { category in
                                    Button {
                                        editBlockCategory = category
                                        editBlockSubcategory = ""
                                    } label: {
                                        HStack(spacing: 4) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(category.color)
                                                .frame(width: 3, height: 14)
                                            Text(category.displayName)
                                                .font(Theme.caption())
                                                .fontWeight(.medium)
                                        }
                                        .padding(.horizontal, Theme.spacingSM)
                                        .padding(.vertical, Theme.spacingXS)
                                        .foregroundColor(editBlockCategory == category ? Theme.selectionForeground : Theme.textSecondary)
                                        .background(editBlockCategory == category ? Theme.selectionBackground : Theme.backgroundCard)
                                        .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("SUBCATEGORY")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)

                        let subcategories = dataStore.subcategories(for: editBlockCategory)

                        if subcategories.isEmpty && !showNewTodaySubcategory {
                            Button {
                                showNewTodaySubcategory = true
                            } label: {
                                HStack {
                                    Image(systemName: "plus")
                                        .font(.system(size: 10))
                                    Text("Add subcategory")
                                        .font(Theme.caption())
                                }
                                .foregroundColor(Theme.textSecondary)
                                .padding(.horizontal, Theme.spacingSM)
                                .padding(.vertical, Theme.spacingXS)
                                .background(Theme.backgroundCard)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: Theme.spacingSM) {
                                    Button {
                                        editBlockSubcategory = ""
                                    } label: {
                                        Text("None")
                                            .font(Theme.caption())
                                            .foregroundColor(editBlockSubcategory.isEmpty ? Theme.selectionForeground : Theme.textTertiary)
                                            .padding(.horizontal, Theme.spacingSM)
                                            .padding(.vertical, Theme.spacingXS)
                                            .background(editBlockSubcategory.isEmpty ? Theme.selectionBackground : Theme.backgroundCard)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)

                                    ForEach(subcategories, id: \.self) { subcategory in
                                        Button {
                                            editBlockSubcategory = subcategory
                                        } label: {
                                            Text(subcategory)
                                                .font(Theme.caption())
                                                .foregroundColor(editBlockSubcategory == subcategory ? Theme.selectionForeground : Theme.textSecondary)
                                                .padding(.horizontal, Theme.spacingSM)
                                                .padding(.vertical, Theme.spacingXS)
                                                .background(editBlockSubcategory == subcategory ? Theme.selectionBackground : Theme.backgroundCard)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Button {
                                        showNewTodaySubcategory = true
                                    } label: {
                                        Image(systemName: "plus")
                                            .font(.system(size: 10, weight: .semibold))
                                            .foregroundColor(Theme.textSecondary)
                                            .frame(width: 24, height: 24)
                                            .background(Theme.backgroundCard)
                                            .clipShape(Circle())
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }

                        if showNewTodaySubcategory {
                            HStack(spacing: Theme.spacingSM) {
                                TextField("New subcategory", text: $newTodaySubcategoryName)
                                    .font(Theme.body2())
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(Theme.spacingSM)
                                    .background(Theme.backgroundCard)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))

                                Button {
                                    let trimmed = newTodaySubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmed.isEmpty else { return }
                                    dataStore.addSubcategory(trimmed, to: editBlockCategory)
                                    editBlockSubcategory = trimmed
                                    newTodaySubcategoryName = ""
                                    showNewTodaySubcategory = false
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(Theme.success)
                                }

                                Button {
                                    showNewTodaySubcategory = false
                                    newTodaySubcategoryName = ""
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("PRIORITY")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)

                        HStack(spacing: Theme.spacingSM) {
                            ForEach(BlockPriority.allCases) { priority in
                                Button {
                                    editBlockPriority = priority
                                } label: {
                                    Text(priority.displayName)
                                        .font(Theme.caption())
                                        .fontWeight(.medium)
                                        .padding(.horizontal, Theme.spacingMD)
                                        .padding(.vertical, Theme.spacingSM)
                                        .foregroundColor(editBlockPriority == priority ? Theme.selectionForeground : Theme.textSecondary)
                                        .background(editBlockPriority == priority ? Theme.selectionBackground : Theme.backgroundCard)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("FLOW LOGIC")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)

                        HStack(spacing: Theme.spacingSM) {
                            ForEach(FlowLogic.allCases) { logic in
                                Button {
                                    editBlockFlowLogic = logic
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: logic == .flowing ? "wind" : "lock.fill")
                                            .font(.system(size: 14))
                                        Text(logic.displayName)
                                            .font(Theme.caption())
                                            .fontWeight(.medium)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(Theme.spacingSM)
                                    .foregroundColor(editBlockFlowLogic == logic ? Theme.selectionForeground : Theme.textSecondary)
                                    .background(editBlockFlowLogic == logic ? Theme.selectionBackground : Theme.backgroundCard)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: Theme.spacingMD) {
                        Text("REAL TIME ANCHOR")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)

                        Toggle(isOn: $editBlockHasFixedStartTime) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Fix start time")
                                    .font(Theme.body2())
                                    .foregroundColor(Theme.textPrimary)

                                Text("Keep this block glued to a specific clock start inside the day.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .tint(Theme.accent)

                        if editBlockHasFixedStartTime {
                            DatePicker(
                                "Starts at",
                                selection: $editBlockFixedStartTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.compact)
                            .foregroundColor(Theme.textPrimary)
                            .tint(Theme.accent)

                            Toggle(isOn: $editBlockFixTimeframeToo) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Fix timeframe too")
                                        .font(Theme.body2())
                                        .foregroundColor(Theme.textPrimary)

                                    Text("Protect this duration from automatic schedule recalibration.")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                            .tint(Theme.accent)
                        }
                    }
                    .padding(Theme.spacingMD)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))

                    CueButton(title: "Save Block", icon: "checkmark") {
                        saveTodayBlockChanges()
                    }
                    .disabled(editBlockName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(editBlockName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                    Spacer(minLength: Theme.spacingXL)
                }
                .padding(.horizontal, Theme.spacingMD)
            }
        }
    }

    private var lazyStartSheet: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    Text("Late Start")
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)

                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        Text("When should today end?")
                            .font(Theme.body1())
                            .fontWeight(.medium)
                            .foregroundColor(Theme.textPrimary)

                        Text("The formula will be recalibrated so the schedule finishes by the time you choose.")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)
                            .lineSpacing(2)
                    }

                    Group {
                        if usesCompactLazyStartLayout {
                            DatePicker(
                                "End time",
                                selection: $lazyStartEndTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.compact)
                            .labelsHidden()
                        } else {
                            DatePicker(
                                "End time",
                                selection: $lazyStartEndTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, usesCompactLazyStartLayout ? Theme.spacingXS : 0)

                    CueCard {
                        VStack(alignment: .leading, spacing: Theme.spacingXS) {
                            Text("RECALIBRATED DAY")
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)

                            Text("\(lazyStartPreviewLabel) total")
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.textPrimary)

                            Text("Ends by \(formattedLazyStartEndTime)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }

                    HStack(spacing: Theme.spacingSM) {
                        Button {
                            showLazyStartSheet = false
                        } label: {
                            Text("Cancel")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                        }
                        .buttonStyle(.plain)

                        Button {
                            startWithLazyEndTime()
                        } label: {
                            Text("Recalibrate & Start")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.onAccent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.accent)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(Theme.spacingMD)
                .padding(.bottom, Theme.spacingXL)
            }
        }
    }

    private var commitmentRatingSheet: some View {
        let clearAction: (() -> Void)? = commitmentBlock?.commitmentRating == nil ? nil : {
            clearCommitmentRating()
        }

        return CommitmentRatingSheet(
            blockName: commitmentBlock?.name ?? "Block",
            rating: $draftCommitmentRating,
            onClear: clearAction,
            onSave: saveCommitmentRating
        )
    }

    private var commitmentBlock: Block? {
        guard let commitmentBlockID,
              let index = viewModel.blockIndex(for: commitmentBlockID),
              engine.blocks.indices.contains(index) else { return nil }
        return engine.blocks[index]
    }

    private func prepareTodayBlockEditor(for blockID: UUID) {
        guard let index = viewModel.blockIndex(for: blockID), engine.blocks.indices.contains(index) else { return }
        let block = engine.blocks[index]

        editingBlockID = block.id
        editBlockName = block.name
        editBlockDuration = max(5, block.duration / 60)
        editBlockCategory = block.category
        editBlockSubcategory = block.subcategory
        editBlockFlowLogic = block.flowLogic
        editBlockPriority = block.priority
        editBlockHasFixedStartTime = block.fixedStartSecondsFromMidnight != nil
        editBlockFixedStartTime = dateFromSecondsFromMidnight(block.fixedStartSecondsFromMidnight ?? (13 * 3600))
        editBlockFixTimeframeToo = block.isTimeframeFixed
        showNewTodaySubcategory = false
        newTodaySubcategoryName = ""
        showEditBlockSheet = true
    }

    private func saveTodayBlockChanges() {
        guard let editingBlockID,
              let index = viewModel.blockIndex(for: editingBlockID),
              engine.blocks.indices.contains(index) else { return }

        let existing = engine.blocks[index]
        let updated = Block(
            id: existing.id,
            name: editBlockName.trimmingCharacters(in: .whitespacesAndNewlines),
            duration: editBlockDuration * 60,
            category: editBlockCategory,
            subcategory: editBlockSubcategory.trimmingCharacters(in: .whitespacesAndNewlines),
            priority: editBlockPriority,
            flowLogic: editBlockFlowLogic,
            colorHex: existing.colorHex,
            details: existing.details,
            isChecked: existing.isChecked,
            commitmentRating: existing.commitmentRating,
            isSmallRepeatable: existing.isSmallRepeatable,
            repeatInterval: existing.repeatInterval,
            miniFormulaId: existing.miniFormulaId,
            miniBlocks: existing.miniBlocks,
            scheduledTime: existing.scheduledTime,
            fixedStartSecondsFromMidnight: editBlockHasFixedStartTime ? secondsFromMidnight(for: editBlockFixedStartTime) : nil,
            isTimeframeFixed: editBlockHasFixedStartTime && editBlockFixTimeframeToo
        )

        viewModel.updateBlock(updated)
        showEditBlockSheet = false
    }

    private func prepareCommitmentRating(for blockID: UUID) {
        guard let index = viewModel.blockIndex(for: blockID), engine.blocks.indices.contains(index) else { return }
        let block = engine.blocks[index]
        guard block.isChecked else { return }

        commitmentBlockID = block.id
        draftCommitmentRating = block.commitmentRating ?? 5
        showCommitmentRatingSheet = true
    }

    private func saveCommitmentRating() {
        guard let commitmentBlockID else { return }
        viewModel.updateCommitmentRating(draftCommitmentRating, forBlockWithID: commitmentBlockID)
        showCommitmentRatingSheet = false
        self.commitmentBlockID = nil
    }

    private func clearCommitmentRating() {
        guard let commitmentBlockID else { return }
        viewModel.updateCommitmentRating(nil, forBlockWithID: commitmentBlockID)
        showCommitmentRatingSheet = false
        self.commitmentBlockID = nil
    }

    private func handleStartTapped() {
        if shouldPromptForLazyStart {
            lazyStartEndTime = defaultLazyStartEndTime()
            showLazyStartSheet = true
        } else {
            viewModel.startDay()
        }
    }

    private func defaultLazyStartEndTime() -> Date {
        let predictedEnd = Date().addingTimeInterval(engine.targetDuration)
        return predictedEnd
    }

    private func startWithLazyEndTime() {
        viewModel.startDay(endingAt: resolvedLazyStartEndTime)
        showLazyStartSheet = false
    }

    private var formattedLazyStartEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: resolvedLazyStartEndTime)
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

    private func secondsFromMidnight(for date: Date) -> TimeInterval {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        let hours = Double(components.hour ?? 0)
        let minutes = Double(components.minute ?? 0)
        return (hours * 3600) + (minutes * 60)
    }

    private func dateFromSecondsFromMidnight(_ seconds: TimeInterval) -> Date {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .second, value: Int(seconds), to: midnight) ?? Date()
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
                        viewModel.selectTodayFormula(formula)
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

private struct TodayBlockDropDelegate: DropDelegate {
    let item: Block
    @Binding var blocks: [Block]
    @Binding var draggedBlock: Block?
    let onReorder: (IndexSet, Int) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedBlock, draggedBlock.id != item.id else { return }
        guard let fromIndex = blocks.firstIndex(where: { $0.id == draggedBlock.id }) else { return }
        guard let toIndex = blocks.firstIndex(where: { $0.id == item.id }) else { return }
        guard blocks.indices.contains(fromIndex), blocks.indices.contains(toIndex) else { return }

        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.86)) {
            onReorder(
                IndexSet(integer: fromIndex),
                toIndex > fromIndex ? toIndex + 1 : toIndex
            )
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedBlock = nil
        return true
    }
}

private struct TodayBlockEndDropDelegate: DropDelegate {
    @Binding var blocks: [Block]
    @Binding var draggedBlock: Block?
    let onReorderToEnd: () -> Void

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard draggedBlock != nil else { return false }

        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.86)) {
            onReorderToEnd()
        }

        draggedBlock = nil
        return true
    }
}
