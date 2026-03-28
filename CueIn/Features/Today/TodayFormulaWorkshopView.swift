//
//  TodayFormulaWorkshopView.swift
//  CueIn
//
//  Compact formula workshop for Today — quick block adds and save-as-new.
//

import SwiftUI

struct TodayFormulaWorkshopView: View {
    @EnvironmentObject var dataStore: DataStore
    @ObservedObject var viewModel: TodayViewModel

    @State private var blockName: String = ""
    @State private var blockDurationMinutes: Double = 30
    @State private var blockCategory: BlockCategory = .custom
    @State private var blockSubcategory: String = ""
    @State private var blockPriority: BlockPriority = .medium
    @State private var blockFlowLogic: FlowLogic = .flowing
    @State private var insertAfterCurrent: Bool = true
    @State private var selectedMiniFormulaID: UUID? = nil
    @State private var hasCustomizedPriority: Bool = false
    @State private var showBlockLibraryPicker: Bool = false
    @State private var saveBlockToLibrary: Bool = false

    @State private var saveFormulaName: String = ""
    @State private var saveFormulaEmoji: String = "⚡"
    @State private var saveConfirmation: String = ""

    @Environment(\.dismiss) private var dismiss

    private var selectedMiniFormula: Formula? {
        guard let selectedMiniFormulaID else { return nil }
        return viewModel.availableMiniFormulas.first(where: { $0.id == selectedMiniFormulaID })
    }

    private var blockDurationRange: ClosedRange<Double> {
        5...max(240, viewModel.engine.targetDuration / 60)
    }

    private var currentFormulaLabel: String {
        viewModel.formulaName.isEmpty ? "Today Draft" : viewModel.formulaName
    }

    private var totalPlannedToday: String {
        StatsEngine.formatDuration(viewModel.engine.blocks.reduce(0.0) { $0 + $1.duration })
    }

    private var hasSavedBlocks: Bool {
        !dataStore.blockLibrary.isEmpty
    }

    init(viewModel: TodayViewModel) {
        self.viewModel = viewModel
        let initialName = viewModel.formulaName.trimmingCharacters(in: .whitespacesAndNewlines)
        _saveFormulaName = State(initialValue: initialName.isEmpty ? "Today Variation" : "\(initialName) Copy")
        _saveFormulaEmoji = State(initialValue: viewModel.currentTodayFormula?.emoji ?? "⚡")
        let initialCategory: BlockCategory = .custom
        _blockCategory = State(initialValue: initialCategory)
        _blockPriority = State(initialValue: viewModel.suggestedPriority(for: initialCategory))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundSecondary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        summaryCard
                        addBlockCard
                        saveFormulaCard
                    }
                    .padding(.horizontal, Theme.spacingMD)
                    .padding(.bottom, Theme.spacingXL)
                }
            }
            .navigationTitle("Today Workshop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showBlockLibraryPicker) {
            BlockLibraryPickerView { item in
                applyBlockLibraryItem(item)
            }
            .environmentObject(dataStore)
        }
    }

    private var summaryCard: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Text("This is a quick formula workshop for Today only.")
                    .font(Theme.body1())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Text("Add blocks into the live schedule without leaving Today, then save that version as a reusable formula if it turns out good.")
                    .font(Theme.body2())
                    .foregroundColor(Theme.textSecondary)

                HStack(spacing: Theme.spacingSM) {
                    summaryPill(title: "Current", value: currentFormulaLabel)
                    summaryPill(title: "Blocks", value: "\(viewModel.engine.blocks.count)")
                    summaryPill(title: "Planned", value: totalPlannedToday)
                }
            }
        }
        .padding(.top, Theme.spacingSM)
    }

    private var addBlockCard: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                Text("Quick Add Block")
                    .font(Theme.body1())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

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
                        .background(Theme.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                    }
                    .buttonStyle(.plain)
                }

                TextField("Block name", text: $blockName)
                    .font(Theme.body1())
                    .foregroundColor(Theme.textPrimary)
                    .padding(Theme.spacingMD)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    label("DURATION")

                    HStack {
                        Text("\(Int((selectedMiniFormula?.totalBlocksDuration ?? (blockDurationMinutes * 60)) / 60))m")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.accent)
                            .frame(width: 60)

                        Slider(value: $blockDurationMinutes, in: blockDurationRange, step: 5)
                            .tint(Theme.accent)
                            .disabled(selectedMiniFormula != nil)
                    }

                    if selectedMiniFormula != nil {
                        Text("Duration is synced from the selected mini-formula.")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    label("MINI-FORMULA")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.spacingSM) {
                            capsuleButton(title: "None", isSelected: selectedMiniFormulaID == nil) {
                                selectedMiniFormulaID = nil
                            }

                            ForEach(viewModel.availableMiniFormulas) { mini in
                                capsuleButton(title: mini.name, isSelected: selectedMiniFormulaID == mini.id) {
                                    selectedMiniFormulaID = mini.id
                                    blockDurationMinutes = max(5, mini.totalBlocksDuration / 60)
                                    if blockName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                        blockName = mini.name
                                    }
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    label("CATEGORY")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.spacingSM) {
                            ForEach(BlockCategory.allCases) { category in
                                Button {
                                    blockCategory = category
                                    if !hasCustomizedPriority {
                                        blockPriority = viewModel.suggestedPriority(for: category)
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
                                    .foregroundColor(blockCategory == category ? Theme.selectionForeground : Theme.textSecondary)
                                    .background(blockCategory == category ? Theme.selectionBackground : Theme.backgroundCard)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    label("SUBCATEGORY")

                    TextField("Optional subcategory", text: $blockSubcategory)
                        .font(Theme.body2())
                        .foregroundColor(Theme.textPrimary)
                        .padding(Theme.spacingMD)
                        .background(Theme.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                }

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    label("PRIORITY")

                    HStack(spacing: Theme.spacingSM) {
                        ForEach(BlockPriority.allCases) { priority in
                            capsuleButton(title: priority.displayName, isSelected: blockPriority == priority) {
                                blockPriority = priority
                                hasCustomizedPriority = true
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    label("FLOW")

                    HStack(spacing: Theme.spacingSM) {
                        ForEach(FlowLogic.allCases) { flowLogic in
                            capsuleButton(title: flowLogic.displayName, isSelected: blockFlowLogic == flowLogic) {
                                blockFlowLogic = flowLogic
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    label("PLACE BLOCK")

                    HStack(spacing: Theme.spacingSM) {
                        capsuleButton(title: "Next", isSelected: insertAfterCurrent) {
                            insertAfterCurrent = true
                        }

                        capsuleButton(title: "At End", isSelected: !insertAfterCurrent) {
                            insertAfterCurrent = false
                        }
                    }
                }

                Toggle(isOn: $saveBlockToLibrary) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Save to library")
                            .font(Theme.body2())
                            .foregroundColor(Theme.textPrimary)

                        Text("Keep this block as a reusable template for future formulas.")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
                .tint(Theme.accent)
                .padding(Theme.spacingMD)
                .background(Theme.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))

                CueButton(title: "Add to Today", icon: "plus") {
                    let duration = selectedMiniFormula?.totalBlocksDuration ?? (blockDurationMinutes * 60)
                    let trimmedName = blockName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let trimmedSubcategory = blockSubcategory.trimmingCharacters(in: .whitespacesAndNewlines)

                    if saveBlockToLibrary {
                        dataStore.saveBlockLibraryItem(
                            from: Block(
                                name: trimmedName,
                                duration: duration,
                                category: blockCategory,
                                subcategory: trimmedSubcategory,
                                priority: blockPriority,
                                flowLogic: blockFlowLogic,
                                colorHex: blockCategory.defaultColorHex,
                                miniFormulaId: selectedMiniFormulaID
                            )
                        )
                    }

                    viewModel.addBlockFromTodayWorkshop(
                        name: trimmedName,
                        duration: duration,
                        category: blockCategory,
                        subcategory: trimmedSubcategory,
                        priority: blockPriority,
                        flowLogic: blockFlowLogic,
                        miniFormulaId: selectedMiniFormulaID,
                        insertAfterCurrent: insertAfterCurrent
                    )
                    resetBlockForm()
                }
                .disabled(blockName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(blockName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)
            }
        }
    }

    private var saveFormulaCard: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                Text("Save Today As New Formula")
                    .font(Theme.body1())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Text("This keeps the current Today arrangement as a reusable full formula without overwriting the original.")
                    .font(Theme.body2())
                    .foregroundColor(Theme.textSecondary)

                HStack(spacing: Theme.spacingSM) {
                    TextField("⚡", text: $saveFormulaEmoji)
                        .font(.system(size: 24))
                        .multilineTextAlignment(.center)
                        .frame(width: 60)
                        .padding(.vertical, 10)
                        .background(Theme.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))

                    TextField("Formula name", text: $saveFormulaName)
                        .font(Theme.body1())
                        .foregroundColor(Theme.textPrimary)
                        .padding(Theme.spacingMD)
                        .background(Theme.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                }

                CueButton(title: "Save as New Formula", icon: "square.and.arrow.down") {
                    if let saved = viewModel.saveTodayAsNewFormula(name: saveFormulaName, emoji: saveFormulaEmoji) {
                        saveConfirmation = "Saved \(saved.name)"
                    }
                }
                .disabled(viewModel.engine.blocks.isEmpty || saveFormulaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(viewModel.engine.blocks.isEmpty || saveFormulaName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1)

                if !saveConfirmation.isEmpty {
                    Text(saveConfirmation)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(Theme.success)
                }
            }
        }
    }

    private func summaryPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textTertiary)
                .lineLimit(1)

            Text(value)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(Theme.spacingSM)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption())
            .foregroundColor(Theme.textTertiary)
    }

    private func capsuleButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.caption())
                .fontWeight(.medium)
                .foregroundColor(isSelected ? Theme.selectionForeground : Theme.textSecondary)
                .padding(.horizontal, Theme.spacingMD)
                .padding(.vertical, Theme.spacingSM)
                .background(isSelected ? Theme.selectionBackground : Theme.backgroundCard)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func resetBlockForm() {
        blockName = ""
        blockDurationMinutes = 30
        blockCategory = .custom
        blockSubcategory = ""
        blockPriority = viewModel.suggestedPriority(for: .custom)
        blockFlowLogic = .flowing
        insertAfterCurrent = true
        selectedMiniFormulaID = nil
        hasCustomizedPriority = false
        saveBlockToLibrary = false
    }

    private func applyBlockLibraryItem(_ item: BlockLibraryItem) {
        blockName = item.name
        blockDurationMinutes = max(5, item.duration / 60)
        blockCategory = item.category
        blockSubcategory = item.subcategory
        blockPriority = item.priority
        blockFlowLogic = item.flowLogic
        selectedMiniFormulaID = item.miniFormulaId
        hasCustomizedPriority = true
    }
}
