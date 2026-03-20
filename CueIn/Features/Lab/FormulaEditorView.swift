//
//  FormulaEditorView.swift
//  CueIn
//
//  Create/edit formulas — blocks with subcategory, priority.
//  Mini-formula constraints: 10min – 6hrs.
//

import SwiftUI

struct FormulaEditorView: View {
    @ObservedObject var viewModel: LabViewModel
    @EnvironmentObject var dataStore: DataStore
    
    @State private var formula: Formula
    @State private var showAddBlock: Bool = false
    
    // Add block form state
    @State private var newBlockName: String = ""
    @State private var newBlockDuration: Double = 30
    @State private var newBlockCategory: BlockCategory = .custom
    @State private var newBlockSubcategory: String = ""
    @State private var newBlockFlowLogic: FlowLogic = .flowing
    @State private var newBlockPriority: BlockPriority = .medium
    @State private var showNewSubcategory: Bool = false
    @State private var newSubcategoryName: String = ""
    
    @Environment(\.dismiss) private var dismiss
    
    let isNew: Bool
    
    init(viewModel: LabViewModel, formula: Formula?) {
        self.viewModel = viewModel
        self.isNew = formula == nil
        if let formula = formula {
            _formula = State(initialValue: formula)
        } else {
            _formula = State(initialValue: Formula(name: "", type: viewModel.newFormulaType))
        }
    }
    
    // Duration constraints based on formula type
    private var durationRange: ClosedRange<Double> {
        formula.type == .mini ? 0.166...6 : 4...20
    }
    
    private var durationStep: Double {
        formula.type == .mini ? 0.166 : 1
    }
    
    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Nav Bar
                HStack {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.textSecondary)
                    
                    Spacer()
                    
                    Text(isNew ? "New \(formula.type == .mini ? "Mini-" : "")Formula" : "Edit Formula")
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Button("Save") {
                        viewModel.saveFormula(formula)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(formula.name.isEmpty ? Theme.textTertiary : .white)
                    .disabled(formula.name.isEmpty)
                }
                .padding(Theme.spacingMD)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        // Formula name
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
                        
                        // Target hours
                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                            Text("TARGET DURATION")
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)
                            
                            HStack {
                                Text(formula.formattedTargetDuration)
                                    .font(.system(size: 28, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .frame(width: 70)
                                
                                Slider(
                                    value: Binding(
                                        get: { Double(formula.targetDuration / 3600) },
                                        set: { formula.targetDuration = $0 * 3600 }
                                    ),
                                    in: durationRange,
                                    step: durationStep
                                )
                                .tint(.white)
                            }
                            
                            if formula.type == .mini {
                                Text("Mini-formulas: 10 min – 6 hours")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        
                        // Fill indicator
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
                        
                        // Blocks
                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                            HStack {
                                Text("BLOCKS (\(formula.blocks.count))")
                                    .font(Theme.caption())
                                    .foregroundColor(Theme.textTertiary)
                                
                                Spacer()
                                
                                Button(action: { showAddBlock = true }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 22))
                                        .foregroundColor(.white)
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
                                ForEach(Array(formula.blocks.enumerated()), id: \.element.id) { index, block in
                                    BlockRowView(block: block) {
                                        formula.blocks.remove(at: index)
                                    }
                                }
                            }
                        }
                        
                        // Explanation
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
                        
                        // Delete Formula
                        if !isNew {
                            Button {
                                viewModel.deleteFormula(formula.id)
                                dismiss()
                            } label: {
                                HStack {
                                    Spacer()
                                    Label("Delete Formula", systemImage: "trash")
                                        .font(Theme.body2())
                                        .foregroundColor(Theme.error)
                                    Spacer()
                                }
                                .padding(Theme.spacingMD)
                                .background(Theme.error.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                            }
                        }
                    }
                    .padding(.horizontal, Theme.spacingMD)
                    .padding(.bottom, Theme.spacingXL)
                }
            }
        }
        .sheet(isPresented: $showAddBlock) {
            addBlockSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
    
    // MARK: - Add Block Sheet (with subcategory + priority)
    
    private var addBlockSheet: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingMD) {
                    Text("Add Block")
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)
                        .padding(.top, Theme.spacingLG)
                    
                    // Name
                    TextField("Block name", text: $newBlockName)
                        .font(Theme.body1())
                        .foregroundColor(Theme.textPrimary)
                        .padding(Theme.spacingMD)
                        .background(Theme.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                    
                    // Duration
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("DURATION")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)
                        
                        HStack {
                            Text("\(Int(newBlockDuration))m")
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .frame(width: 55)
                            
                            Slider(value: $newBlockDuration, in: 5...240, step: 5)
                                .tint(.white)
                        }
                    }
                    
                    // Category
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("CATEGORY")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.spacingSM) {
                                ForEach(BlockCategory.allCases) { cat in
                                    Button(action: {
                                        newBlockCategory = cat
                                        newBlockSubcategory = ""
                                    }) {
                                        HStack(spacing: 4) {
                                            RoundedRectangle(cornerRadius: 2)
                                                .fill(cat.color)
                                                .frame(width: 3, height: 14)
                                            Text(cat.displayName)
                                                .font(Theme.caption())
                                                .fontWeight(.medium)
                                        }
                                        .padding(.horizontal, Theme.spacingSM)
                                        .padding(.vertical, Theme.spacingXS)
                                        .foregroundColor(newBlockCategory == cat ? .white : Theme.textSecondary)
                                        .background(newBlockCategory == cat ? Theme.backgroundElevated : Theme.backgroundCard)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(newBlockCategory == cat ? cat.color.opacity(0.5) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    // Subcategory
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("SUBCATEGORY")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)
                        
                        let subs = dataStore.subcategories(for: newBlockCategory)
                        
                        if subs.isEmpty && !showNewSubcategory {
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
                                    // None option
                                    Button { newBlockSubcategory = "" } label: {
                                        Text("None")
                                            .font(Theme.caption())
                                            .foregroundColor(newBlockSubcategory.isEmpty ? .white : Theme.textTertiary)
                                            .padding(.horizontal, Theme.spacingSM)
                                            .padding(.vertical, Theme.spacingXS)
                                            .background(newBlockSubcategory.isEmpty ? Theme.backgroundElevated : Theme.backgroundCard)
                                            .clipShape(Capsule())
                                    }
                                    .buttonStyle(.plain)
                                    
                                    ForEach(subs, id: \.self) { sub in
                                        Button { newBlockSubcategory = sub } label: {
                                            Text(sub)
                                                .font(Theme.caption())
                                                .foregroundColor(newBlockSubcategory == sub ? .white : Theme.textSecondary)
                                                .padding(.horizontal, Theme.spacingSM)
                                                .padding(.vertical, Theme.spacingXS)
                                                .background(newBlockSubcategory == sub ? Theme.backgroundElevated : Theme.backgroundCard)
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    
                                    // + New
                                    Button { showNewSubcategory = true } label: {
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
                                    if !newSubcategoryName.isEmpty {
                                        dataStore.addSubcategory(newSubcategoryName, to: newBlockCategory)
                                        newBlockSubcategory = newSubcategoryName
                                        newSubcategoryName = ""
                                        showNewSubcategory = false
                                    }
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
                    
                    // Priority
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("PRIORITY")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)
                        
                        HStack(spacing: Theme.spacingSM) {
                            ForEach(BlockPriority.allCases) { priority in
                                Button { newBlockPriority = priority } label: {
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
                                    .foregroundColor(newBlockPriority == priority ? .white : Theme.textSecondary)
                                    .background(newBlockPriority == priority ? Theme.backgroundElevated : Theme.backgroundCard)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Text("Higher priority blocks get extra time when others finish early")
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }
                    
                    // Flow logic
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text("FLOW LOGIC")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)
                        
                        HStack(spacing: Theme.spacingSM) {
                            ForEach(FlowLogic.allCases) { logic in
                                Button(action: { newBlockFlowLogic = logic }) {
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
                                    .foregroundColor(newBlockFlowLogic == logic ? .white : Theme.textSecondary)
                                    .background(newBlockFlowLogic == logic ? Theme.backgroundElevated : Theme.backgroundCard)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    CueButton(title: "Add Block", icon: "plus") {
                        let block = Block(
                            name: newBlockName,
                            duration: newBlockDuration * 60,
                            category: newBlockCategory,
                            subcategory: newBlockSubcategory,
                            priority: newBlockPriority,
                            flowLogic: newBlockFlowLogic,
                            colorHex: newBlockCategory.color.description
                        )
                        formula.blocks.append(block)
                        newBlockName = ""
                        newBlockDuration = 30
                        newBlockSubcategory = ""
                        newBlockPriority = .medium
                        showAddBlock = false
                    }
                    .disabled(newBlockName.isEmpty)
                    .opacity(newBlockName.isEmpty ? 0.5 : 1)
                    .padding(.bottom, Theme.spacingXL)
                }
                .padding(.horizontal, Theme.spacingMD)
            }
        }
    }
}
