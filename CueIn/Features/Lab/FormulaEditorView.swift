//
//  FormulaEditorView.swift
//  CueIn
//
//  Create and edit formulas, including block updates and ordering.
//

import SwiftUI
import UniformTypeIdentifiers

struct FormulaEditorView: View {
    @ObservedObject var viewModel: LabViewModel
    @EnvironmentObject var dataStore: DataStore
    @AppStorage(TimeMagnetSetting.storageKey) private var isTimeMagnetEnabledGlobally = TimeMagnetSetting.defaultValue

    @State private var formula: Formula
    @State private var showBlockEditor: Bool = false
    @State private var showBlockLibraryPicker: Bool = false
    @State private var editingBlockIndex: Int? = nil
    @State private var activeSwipeBlockID: UUID? = nil
    @State private var draggedBlock: Block? = nil

    // Block form state
    @State private var newBlockName: String = ""
    @State private var newBlockDuration: Double = 30
    @State private var newBlockCategory: BlockCategory = .custom
    @State private var newBlockSubcategory: String = ""
    @State private var newBlockFlowLogic: FlowLogic = .flowing
    @State private var newBlockPriority: BlockPriority = .medium
    @State private var newBlockMiniFormulaId: UUID? = nil
    @State private var hasFixedBlockStartTime: Bool = false
    @State private var fixedBlockStartTime: Date = Date()
    @State private var fixBlockTimeframeToo: Bool = false
    @State private var showNewSubcategory: Bool = false
    @State private var newSubcategoryName: String = ""
    @State private var hasCustomizedNewBlockPriority: Bool = false
    @State private var saveBlockToLibrary: Bool = false

    @Environment(\.dismiss) private var dismiss

    let isNew: Bool

    init(viewModel: LabViewModel, formula: Formula?) {
        self.viewModel = viewModel
        self.isNew = formula == nil

        if let formula {
            _formula = State(initialValue: formula)
        } else {
            _formula = State(initialValue: Formula(name: "", type: viewModel.newFormulaType))
        }
    }

    private var durationRange: ClosedRange<Double> {
        formula.type == .mini ? 0.166...6 : 4...20
    }

    private var durationStep: Double {
        formula.type == .mini ? 0.166 : 1
    }

    private var blockDurationRange: ClosedRange<Double> {
        5...max(240, formula.targetDuration / 60)
    }

    private var blockEditorTitle: String {
        editingBlockIndex == nil ? "Add Block" : "Edit Block"
    }

    private var blockEditorActionTitle: String {
        editingBlockIndex == nil ? "Add Block" : "Save Changes"
    }

    private var scheduledTimeLabel: String {
        StatsEngine.formatDuration(formula.totalBlocksDuration)
    }

    private var availableMiniFormulas: [Formula] {
        guard formula.type == .full else { return [] }
        return dataStore.formulas.filter { $0.type == .mini && $0.id != formula.id }
    }

    private var selectedMiniFormula: Formula? {
        guard let newBlockMiniFormulaId else { return nil }
        return availableMiniFormulas.first { $0.id == newBlockMiniFormulaId }
    }

    private var hasSavedBlocks: Bool {
        !dataStore.blockLibrary.isEmpty
    }

    private func preferredPriority(for category: BlockCategory) -> BlockPriority {
        dataStore.preferredPriority(for: category) ?? .medium
    }

    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)

                    Spacer()

                    Text(isNew ? "New \(formula.type == .mini ? "Mini-" : "")Formula" : "Edit Formula")
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)

                    Spacer()

                    HStack(spacing: Theme.spacingSM) {
                        editorMenu

                        Button("Save") {
                            viewModel.saveFormula(formula)
                            dismiss()
                        }
                        .fontWeight(.semibold)
                        .foregroundColor(formula.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.textTertiary : Theme.accent)
                        .disabled(formula.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(Theme.spacingMD)

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        formulaHeaderSection
                        categorySummarySection
                        blocksSection
                        explanationSection
                    }
                    .padding(.horizontal, Theme.spacingMD)
                    .padding(.bottom, Theme.spacingXL)
                }
            }
        }
        .sheet(isPresented: $showBlockEditor) {
            blockEditorSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var formulaHeaderSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLG) {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Text("NAME")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)

                TextField("Formula name", text: $formula.name)
                    .font(Theme.body1())
                    .foregroundColor(Theme.textPrimary)
                    .padding(Theme.spacingMD)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
            }

            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Text("TARGET DURATION")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)

                HStack {
                    Text(formula.formattedTargetDuration)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.accent)
                        .frame(width: 70)

                    Slider(
                        value: Binding(
                            get: { Double(formula.targetDuration / 3600) },
                            set: { formula.targetDuration = $0 * 3600 }
                        ),
                        in: durationRange,
                        step: durationStep
                    )
                    .tint(Theme.accent)
                }

                if formula.type == .mini {
                    Text("Mini-formulas: 10 min – 6 hours")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: Theme.spacingXS) {
                CueProgressBar(
                    progress: formula.fillPercentage,
                    height: 4,
                    showLabel: false
                )

                Text("Filled: \(Int(formula.fillPercentage * 100))% • \(StatsEngine.formatDuration(formula.unscheduledTime)) remaining")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    private var categorySummarySection: some View {
        CategoryAllocationCompactStrip(
            title: "CATEGORY SPLIT",
            allocations: formula.categoryAllocations,
            trailingLabel: scheduledTimeLabel
        )
    }

    private var blocksSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack {
                Text("BLOCKS (\(formula.blocks.count))")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)

                Spacer()

                Button(action: { prepareBlockEditor() }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.accent)
                }
            }

            if formula.blocks.isEmpty {
                CueCard {
                    HStack {
                        Spacer()

                        VStack(spacing: Theme.spacingSM) {
                            Image(systemName: "square.stack.3d.up.slash")
                                .font(.system(size: 24))
                                .foregroundColor(Theme.textTertiary)

                            Text("No blocks yet. Tap + to add.")
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, Theme.spacingLG)
                }
            } else {
                Text("Long-press and drag to reorder. Swipe left for block actions.")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)

                ForEach(formula.blocks) { block in
                    BlockRowView(
                        block: block,
                        onTap: { editBlock(withId: block.id) },
                        onEdit: { editBlock(withId: block.id) },
                        onDuplicate: { duplicateBlock(withId: block.id) },
                        onDelete: { removeBlock(withId: block.id) },
                        dragItemProvider: {
                            activeSwipeBlockID = nil
                            draggedBlock = block
                            return NSItemProvider(object: block.id.uuidString as NSString)
                        },
                        activeSwipeBlockID: $activeSwipeBlockID
                    )
                    .onDrop(
                        of: [UTType.text],
                        delegate: FormulaBlockDropDelegate(
                            item: block,
                            blocks: $formula.blocks,
                            draggedBlock: $draggedBlock
                        )
                    )
                }

                Color.clear
                    .frame(height: 12)
                    .onDrop(
                        of: [UTType.text],
                        delegate: FormulaBlockEndDropDelegate(
                            blocks: $formula.blocks,
                            draggedBlock: $draggedBlock
                        )
                    )
            }
        }
    }

    private var explanationSection: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Label("Block types", systemImage: "info.circle")
                    .font(Theme.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textSecondary)

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    explanationRow(icon: "wind", label: "Flowing", text: "auto-advances after timer ends")
                    explanationRow(icon: "lock.fill", label: "Blocking", text: "stays until you check it off")
                }
            }
        }
    }

    private var editorMenu: some View {
        Menu {
            if formula.type == .full {
                Button {
                    formula.timeMagnet.isEnabled.toggle()
                } label: {
                    Label(
                        formula.timeMagnet.isEnabled ? "Turn Time Magnet Off" : "Turn Time Magnet On",
                        systemImage: formula.timeMagnet.isEnabled ? "bolt.slash" : "bolt.badge.clock"
                    )
                }

                Button {
                    isTimeMagnetEnabledGlobally.toggle()
                } label: {
                    Label(
                        isTimeMagnetEnabledGlobally ? "Turn App Magnet Off" : "Turn App Magnet On",
                        systemImage: isTimeMagnetEnabledGlobally ? "switch.2" : "switch.2"
                    )
                }

                Divider()
            }

            Button {
                formula.status = formula.status == .active ? .inactive : .active
            } label: {
                Label(
                    formula.status == .active ? "Mark Formula Inactive" : "Mark Formula Active",
                    systemImage: formula.status == .active ? "eye.slash" : "eye"
                )
            }

            if !isNew {
                Divider()

                Button(role: .destructive) {
                    viewModel.deleteFormula(formula.id)
                    dismiss()
                } label: {
                    Label("Delete Formula", systemImage: "trash")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 28, height: 28)
        }
    }

    private func explanationRow(icon: String, label: String, text: String) -> some View {
        HStack(spacing: Theme.spacingSM) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
                .frame(width: 16)

            Text(label)
                .font(Theme.caption())
                .fontWeight(.semibold)
                .foregroundColor(Theme.textSecondary)

            Text("— \(text)")
                .font(Theme.caption())
                .foregroundColor(Theme.textTertiary)
        }
    }

    private var blockEditorSheet: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingMD) {
                    Text(blockEditorTitle)
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)
                        .padding(.top, Theme.spacingLG)

                    if hasSavedBlocks {
                        Button {
                            showBlockLibraryPicker = true
                        } label: {
                            HStack(spacing: Theme.spacingSM) {
                                Image(systemName: "square.stack.3d.up")
                                    .font(.system(size: 12, weight: .semibold))

                                Text("Use Saved Block")
                                    .font(Theme.body2())
                                    .fontWeight(.semibold)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(Theme.textPrimary)
                            .padding(Theme.spacingMD)
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                        }
                        .buttonStyle(.plain)
                    }

                    TextField("Block name", text: $newBlockName)
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
                            Text("\(Int((selectedMiniFormula?.totalBlocksDuration ?? (newBlockDuration * 60)) / 60))m")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(Theme.accent)
                                .frame(width: 55)

                            Slider(value: $newBlockDuration, in: blockDurationRange, step: 5)
                                .tint(Theme.accent)
                                .disabled(selectedMiniFormula != nil)
                        }

                        if selectedMiniFormula != nil {
                            Text("Duration is synced from the selected mini-formula.")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }

                    if formula.type == .full {
                        VStack(alignment: .leading, spacing: Theme.spacingXS) {
                            Text("MINI-FORMULA (OPTIONAL)")
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)

                            if availableMiniFormulas.isEmpty {
                                Text("Create a mini-formula in Lab to turn this block into a superblock.")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textTertiary)
                                    .padding(Theme.spacingMD)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.backgroundCard)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Theme.spacingSM) {
                                        Button {
                                            selectMiniFormula(nil)
                                        } label: {
                                            Text("None")
                                                .font(Theme.caption())
                                                .fontWeight(.medium)
                                                .padding(.horizontal, Theme.spacingMD)
                                                .padding(.vertical, Theme.spacingSM)
                                                .foregroundColor(newBlockMiniFormulaId == nil ? Theme.selectionForeground : Theme.textSecondary)
                                                .background(newBlockMiniFormulaId == nil ? Theme.selectionBackground : Theme.backgroundCard)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)

                                        ForEach(availableMiniFormulas) { miniFormula in
                                            Button {
                                                selectMiniFormula(miniFormula)
                                            } label: {
                                                HStack(spacing: Theme.spacingXS) {
                                                    Image(systemName: "square.stack.3d.up")
                                                        .font(.system(size: 11, weight: .semibold))
                                                    Text(miniFormula.name)
                                                        .font(Theme.caption())
                                                        .fontWeight(.medium)
                                                }
                                                .padding(.horizontal, Theme.spacingMD)
                                                .padding(.vertical, Theme.spacingSM)
                                                .foregroundColor(newBlockMiniFormulaId == miniFormula.id ? Theme.selectionForeground : Theme.textSecondary)
                                                .background(newBlockMiniFormulaId == miniFormula.id ? Theme.selectionBackground : Theme.backgroundCard)
                                                .clipShape(Capsule())
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }

                                if let selectedMiniFormula {
                                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                                        HStack {
                                            Text(selectedMiniFormula.name)
                                                .font(Theme.body2())
                                                .fontWeight(.semibold)
                                                .foregroundColor(Theme.textPrimary)

                                            Spacer()

                                            Text("\(selectedMiniFormula.blockCount) tasks • \(StatsEngine.formatDuration(selectedMiniFormula.totalBlocksDuration))")
                                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                .foregroundColor(Theme.textSecondary)
                                        }

                                        ForEach(selectedMiniFormula.blocks.prefix(5)) { miniBlock in
                                            HStack(spacing: Theme.spacingSM) {
                                                Circle()
                                                    .stroke(Theme.textTertiary, lineWidth: 1)
                                                    .frame(width: 12, height: 12)

                                                Text(miniBlock.name)
                                                    .font(.system(size: 12))
                                                    .foregroundColor(Theme.textSecondary)

                                                Spacer()

                                                Text(miniBlock.formattedDuration)
                                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                    .foregroundColor(Theme.textTertiary)
                                            }
                                        }

                                        if selectedMiniFormula.blocks.count > 5 {
                                            Text("+\(selectedMiniFormula.blocks.count - 5) more tasks")
                                                .font(.system(size: 11))
                                                .foregroundColor(Theme.textTertiary)
                                        }

                                        Text("This block stays as one superblock in Today and opens its child tasks while active.")
                                            .font(.system(size: 10))
                                            .foregroundColor(Theme.textTertiary)
                                    }
                                    .padding(Theme.spacingMD)
                                    .background(Theme.backgroundCard)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                                }
                            }
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
                                        newBlockCategory = category
                                        newBlockSubcategory = ""
                                        if !hasCustomizedNewBlockPriority {
                                            newBlockPriority = preferredPriority(for: category)
                                        }
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
                                        .foregroundColor(newBlockCategory == category ? Theme.selectionForeground : Theme.textSecondary)
                                        .background(newBlockCategory == category ? Theme.selectionBackground : Theme.backgroundCard)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(newBlockCategory == category ? category.color.opacity(0.5) : Color.clear, lineWidth: 1)
                                        )
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

                        let subcategories = dataStore.subcategories(for: newBlockCategory)

                        if subcategories.isEmpty && !showNewSubcategory {
                            Button {
                                showNewSubcategory = true
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
                                        newBlockSubcategory = ""
                                    } label: {
                                        Text("None")
                                            .font(Theme.caption())
                                            .foregroundColor(newBlockSubcategory.isEmpty ? Theme.selectionForeground : Theme.textTertiary)
                                            .padding(.horizontal, Theme.spacingSM)
                                            .padding(.vertical, Theme.spacingXS)
                                            .background(newBlockSubcategory.isEmpty ? Theme.selectionBackground : Theme.backgroundCard)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)

                                    ForEach(subcategories, id: \.self) { subcategory in
                                        Button {
                                            newBlockSubcategory = subcategory
                                        } label: {
                                            Text(subcategory)
                                                .font(Theme.caption())
                                                .foregroundColor(newBlockSubcategory == subcategory ? Theme.selectionForeground : Theme.textSecondary)
                                                .padding(.horizontal, Theme.spacingSM)
                                                .padding(.vertical, Theme.spacingXS)
                                                .background(newBlockSubcategory == subcategory ? Theme.selectionBackground : Theme.backgroundCard)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Button {
                                        showNewSubcategory = true
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

                        if showNewSubcategory {
                            HStack(spacing: Theme.spacingSM) {
                                TextField("New subcategory", text: $newSubcategoryName)
                                    .font(Theme.body2())
                                    .foregroundColor(Theme.textPrimary)
                                    .padding(Theme.spacingSM)
                                    .background(Theme.backgroundCard)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))

                                Button {
                                    let trimmedName = newSubcategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                                    guard !trimmedName.isEmpty else { return }
                                    dataStore.addSubcategory(trimmedName, to: newBlockCategory)
                                    newBlockSubcategory = trimmedName
                                    newSubcategoryName = ""
                                    showNewSubcategory = false
                                } label: {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(Theme.success)
                                }

                                Button {
                                    showNewSubcategory = false
                                    newSubcategoryName = ""
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
                                    newBlockPriority = priority
                                    hasCustomizedNewBlockPriority = true
                                } label: {
                                    HStack(spacing: 4) {
                                        ForEach(0..<priority.rawValue, id: \.self) { _ in
                                            Image(systemName: "exclamationmark")
                                                .font(.system(size: 8, weight: .bold))
                                        }

                                        Text(priority.displayName)
                                            .font(Theme.caption())
                                            .fontWeight(.medium)
                                    }
                                    .padding(.horizontal, Theme.spacingMD)
                                    .padding(.vertical, Theme.spacingSM)
                                    .foregroundColor(newBlockPriority == priority ? Theme.selectionForeground : Theme.textSecondary)
                                    .background(newBlockPriority == priority ? Theme.selectionBackground : Theme.backgroundCard)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        Text("Higher priority blocks get extra time when others finish early")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }

                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("FLOW LOGIC")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)

                        HStack(spacing: Theme.spacingSM) {
                            ForEach(FlowLogic.allCases) { logic in
                                Button {
                                    newBlockFlowLogic = logic
                                } label: {
                                    VStack(spacing: 4) {
                                        Image(systemName: logic == .flowing ? "wind" : "lock.fill")
                                            .font(.system(size: 14))

                                        Text(logic.displayName)
                                            .font(Theme.caption())
                                            .fontWeight(.medium)

                                        Text(logic == .flowing ? "Auto-advances" : "Until checked")
                                            .font(.system(size: 9))
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(Theme.spacingSM)
                                    .foregroundColor(newBlockFlowLogic == logic ? Theme.selectionForeground : Theme.textSecondary)
                                    .background(newBlockFlowLogic == logic ? Theme.selectionBackground : Theme.backgroundCard)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if formula.type == .full {
                        VStack(alignment: .leading, spacing: Theme.spacingMD) {
                            Text("REAL TIME ANCHOR")
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)

                            Toggle(isOn: $hasFixedBlockStartTime) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Fix start time")
                                        .font(Theme.body2())
                                        .foregroundColor(Theme.textPrimary)

                                    Text("This block keeps the same clock start instead of drifting with the rest of the formula.")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                            .tint(Theme.accent)

                            if hasFixedBlockStartTime {
                                DatePicker(
                                    "Starts at",
                                    selection: $fixedBlockStartTime,
                                    displayedComponents: .hourAndMinute
                                )
                                .datePickerStyle(.compact)
                                .foregroundColor(Theme.textPrimary)
                                .tint(Theme.accent)

                                Toggle(isOn: $fixBlockTimeframeToo) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Fix timeframe too")
                                            .font(Theme.body2())
                                            .foregroundColor(Theme.textPrimary)

                                        Text("Protect this block’s duration from automatic recalibration.")
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
                    }

                    Toggle(isOn: $saveBlockToLibrary) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Save to library")
                                .font(Theme.body2())
                                .foregroundColor(Theme.textPrimary)

                            Text("Keep this block as a reusable template for later.")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    .tint(Theme.accent)
                    .padding(Theme.spacingMD)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))

                    CueButton(
                        title: blockEditorActionTitle,
                        icon: editingBlockIndex == nil ? "plus" : "checkmark"
                    ) {
                        saveBlock()
                    }
                    .disabled(newBlockName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(newBlockName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                    if editingBlockIndex != nil {
                        Button("Cancel Editing") {
                            showBlockEditor = false
                        }
                        .font(Theme.body2())
                        .foregroundColor(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, Theme.spacingXL)
                    } else {
                        Spacer(minLength: Theme.spacingXL)
                    }
                }
                .padding(.horizontal, Theme.spacingMD)
            }
        }
        .sheet(isPresented: $showBlockLibraryPicker) {
            BlockLibraryPickerView { item in
                applyBlockLibraryItem(item)
            }
            .environmentObject(dataStore)
        }
    }

    private func prepareBlockEditor(for index: Int? = nil) {
        editingBlockIndex = index
        showNewSubcategory = false
        newSubcategoryName = ""
        saveBlockToLibrary = false

        if let index, formula.blocks.indices.contains(index) {
            let block = formula.blocks[index]
            newBlockName = block.name
            newBlockDuration = max(5, block.duration / 60)
            newBlockCategory = block.category
            newBlockSubcategory = block.subcategory
            newBlockFlowLogic = block.flowLogic
            newBlockPriority = block.priority
            newBlockMiniFormulaId = block.miniFormulaId
            hasFixedBlockStartTime = block.fixedStartSecondsFromMidnight != nil
            fixedBlockStartTime = dateFromSecondsFromMidnight(block.fixedStartSecondsFromMidnight ?? (13 * 3600))
            fixBlockTimeframeToo = block.isTimeframeFixed
            hasCustomizedNewBlockPriority = true
        } else {
            newBlockName = ""
            newBlockDuration = 30
            newBlockCategory = .custom
            newBlockSubcategory = ""
            newBlockFlowLogic = .flowing
            newBlockPriority = preferredPriority(for: .custom)
            newBlockMiniFormulaId = nil
            hasFixedBlockStartTime = false
            fixedBlockStartTime = dateFromSecondsFromMidnight(13 * 3600)
            fixBlockTimeframeToo = false
            hasCustomizedNewBlockPriority = false
        }

        showBlockEditor = true
    }

    private func saveBlock() {
        let trimmedName = newBlockName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let trimmedSubcategory = newBlockSubcategory.trimmingCharacters(in: .whitespacesAndNewlines)
        let existingBlock = editingBlockIndex.flatMap { index in
            formula.blocks.indices.contains(index) ? formula.blocks[index] : nil
        }

        let block = Block(
            id: existingBlock?.id ?? UUID(),
            name: trimmedName,
            duration: selectedMiniFormula?.totalBlocksDuration ?? (newBlockDuration * 60),
            category: newBlockCategory,
            subcategory: trimmedSubcategory,
            priority: newBlockPriority,
            flowLogic: newBlockFlowLogic,
            colorHex: existingBlock?.colorHex ?? newBlockCategory.defaultColorHex,
            details: existingBlock?.details ?? "",
            isChecked: existingBlock?.isChecked ?? false,
            isSmallRepeatable: existingBlock?.isSmallRepeatable ?? false,
            repeatInterval: existingBlock?.repeatInterval,
            miniFormulaId: newBlockMiniFormulaId,
            scheduledTime: existingBlock?.scheduledTime,
            fixedStartSecondsFromMidnight: hasFixedBlockStartTime ? secondsFromMidnight(for: fixedBlockStartTime) : nil,
            isTimeframeFixed: hasFixedBlockStartTime && fixBlockTimeframeToo
        )

        if let index = editingBlockIndex, formula.blocks.indices.contains(index) {
            formula.blocks[index] = block
        } else {
            formula.blocks.append(block)
        }

        if saveBlockToLibrary {
            dataStore.saveBlockLibraryItem(from: block)
        }

        activeSwipeBlockID = nil
        showBlockEditor = false
    }

    private func editBlock(withId blockID: UUID) {
        guard let index = index(for: blockID) else { return }
        activeSwipeBlockID = nil
        prepareBlockEditor(for: index)
    }

    private func duplicateBlock(withId blockID: UUID) {
        guard let index = index(for: blockID), formula.blocks.indices.contains(index) else { return }

        var copy = formula.blocks[index]
        copy = Block(
            name: copy.name + " Copy",
            duration: copy.duration,
            category: copy.category,
            subcategory: copy.subcategory,
            priority: copy.priority,
            flowLogic: copy.flowLogic,
            colorHex: copy.colorHex,
            details: copy.details,
            isChecked: false,
            isSmallRepeatable: copy.isSmallRepeatable,
            repeatInterval: copy.repeatInterval,
            miniFormulaId: copy.miniFormulaId,
            scheduledTime: copy.scheduledTime,
            fixedStartSecondsFromMidnight: copy.fixedStartSecondsFromMidnight,
            isTimeframeFixed: copy.isTimeframeFixed
        )

        formula.blocks.insert(copy, at: index + 1)
        activeSwipeBlockID = nil
    }

    private func removeBlock(withId blockID: UUID) {
        guard let index = index(for: blockID), formula.blocks.indices.contains(index) else { return }
        formula.blocks.remove(at: index)
        activeSwipeBlockID = nil
    }

    private func index(for blockID: UUID) -> Int? {
        formula.blocks.firstIndex(where: { $0.id == blockID })
    }

    private func selectMiniFormula(_ miniFormula: Formula?) {
        let previousName = availableMiniFormulas.first { $0.id == newBlockMiniFormulaId }?.name

        newBlockMiniFormulaId = miniFormula?.id

        if let miniFormula {
            if newBlockName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || newBlockName == previousName {
                newBlockName = miniFormula.name
            }

            newBlockDuration = max(5, miniFormula.totalBlocksDuration / 60)
        }
    }

    private func applyBlockLibraryItem(_ item: BlockLibraryItem) {
        newBlockName = item.name
        newBlockDuration = max(5, item.duration / 60)
        newBlockCategory = item.category
        newBlockSubcategory = item.subcategory
        newBlockFlowLogic = item.flowLogic
        newBlockPriority = item.priority
        newBlockMiniFormulaId = item.miniFormulaId
        hasFixedBlockStartTime = item.fixedStartSecondsFromMidnight != nil
        fixedBlockStartTime = dateFromSecondsFromMidnight(item.fixedStartSecondsFromMidnight ?? (13 * 3600))
        fixBlockTimeframeToo = item.isTimeframeFixed
        hasCustomizedNewBlockPriority = true
        showNewSubcategory = false
        newSubcategoryName = ""
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
}

private struct FormulaBlockDropDelegate: DropDelegate {
    let item: Block
    @Binding var blocks: [Block]
    @Binding var draggedBlock: Block?

    func dropEntered(info: DropInfo) {
        guard let draggedBlock, draggedBlock.id != item.id else { return }
        guard let fromIndex = blocks.firstIndex(where: { $0.id == draggedBlock.id }) else { return }
        guard let toIndex = blocks.firstIndex(where: { $0.id == item.id }) else { return }
        guard blocks.indices.contains(fromIndex), blocks.indices.contains(toIndex) else { return }

        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.86)) {
            blocks.move(
                fromOffsets: IndexSet(integer: fromIndex),
                toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex
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

private struct FormulaBlockEndDropDelegate: DropDelegate {
    @Binding var blocks: [Block]
    @Binding var draggedBlock: Block?

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard let draggedBlock else { return false }
        guard let fromIndex = blocks.firstIndex(where: { $0.id == draggedBlock.id }) else {
            self.draggedBlock = nil
            return false
        }

        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.86)) {
            let moved = blocks.remove(at: fromIndex)
            blocks.append(moved)
        }

        self.draggedBlock = nil
        return true
    }
}
