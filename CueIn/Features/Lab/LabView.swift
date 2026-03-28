//
//  LabView.swift
//  CueIn
//
//  Main Lab tab — formula, mini-formula, and week schedule management.
//

import SwiftUI

struct LabView: View {
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var viewModel: LabViewModel
    @State private var showWeekEditor: Bool = false
    @State private var showWeekDayEditor: Bool = false
    @State private var showInlineFormulaCreator: Bool = false
    @State private var editingWeekDay: DayOfWeek = .monday
    @State private var weekDayTitle: String = ""
    @State private var weekDayDetails: String = ""
    @State private var selectedFormulaIDs = Set<UUID>()
    @State private var formulaIDsBeforeInlineCreation = Set<UUID>()
    
    init(dataStore: DataStore, engine: FormulaEngine) {
        _viewModel = StateObject(wrappedValue: LabViewModel(dataStore: dataStore))
    }
    
    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    // Header
                    HStack {
                        Text("Lab")
                            .font(Theme.heading1())
                            .foregroundColor(Theme.textPrimary)
                        
                        Spacer()

                        HStack(spacing: Theme.spacingSM) {
                            Menu {
                            Button {
                                viewModel.editingFormula = nil
                                viewModel.newFormulaType = .full
                                viewModel.showFormulaEditor = true
                            } label: {
                                Label("New Formula", systemImage: "doc.badge.plus")
                            }
                            
                            Button {
                                viewModel.editingFormula = nil
                                viewModel.newFormulaType = .mini
                                viewModel.showFormulaEditor = true
                            } label: {
                                Label("New Mini-Formula", systemImage: "bolt.badge.plus")
                            }
                            } label: {
                                Image(systemName: "plus")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(Theme.onAccent)
                                    .frame(width: 32, height: 32)
                                    .background(Theme.accent)
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, Theme.spacingMD)
                    .padding(.top, Theme.spacingSM)
                    
                    // Week Schedule
                    weekScheduleSection
                        .padding(.horizontal, Theme.spacingMD)
                    
                    // Formulas
                    sectionHeader("Formulas")
                    
                    if viewModel.activeFormulas.isEmpty {
                        emptyCard("No formulas yet. Tap + to create one.", icon: "doc.text")
                            .padding(.horizontal, Theme.spacingMD)
                    } else {
                        VStack(spacing: Theme.spacingSM) {
                            ForEach(viewModel.activeFormulas) { formula in
                                FormulaCard(formula: formula) {
                                    viewModel.editFormula(formula)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)
                    }
                    
                    // Mini-Formulas
                    sectionHeader("Mini-Formulas")
                    
                    Text("Quick 15–30 min blocks for roadblock recovery or energy boosts")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                        .padding(.horizontal, Theme.spacingMD)
                    
                    if viewModel.miniFormulas.isEmpty {
                        emptyCard("No mini-formulas. Create one from the + menu.", icon: "bolt")
                            .padding(.horizontal, Theme.spacingMD)
                    } else {
                        VStack(spacing: Theme.spacingSM) {
                            ForEach(viewModel.miniFormulas) { formula in
                                FormulaCard(formula: formula) {
                                    viewModel.editFormula(formula)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)
                    }
                }
                .padding(.bottom, Theme.spacingXL)
            }
        }
        .sheet(isPresented: $viewModel.showFormulaEditor) {
            FormulaEditorView(viewModel: viewModel, formula: viewModel.editingFormula)
        }
        .sheet(isPresented: $showWeekEditor) {
            weekEditorSheet
        }
    }
    
    // MARK: - Week Schedule
    
    private var weekScheduleSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack {
                Text("Week Schedule")
                    .font(Theme.heading3())
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Button("Week Editor") {
                    showWeekEditor = true
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.accent)
            }

            Text("Today stays expanded here. Edit the full week in the dedicated editor.")
                .font(Theme.caption())
                .foregroundColor(Theme.textTertiary)

            WeekOverviewView(viewModel: viewModel)
        }
    }

    private var weekEditorSheet: some View {
        NavigationView {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        VStack(alignment: .leading, spacing: Theme.spacingXS) {
                            Text("Week Editor")
                                .font(Theme.heading2())
                                .foregroundColor(Theme.textPrimary)

                            Text("Set up each day with a name, notes, and one or more formulas.")
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)
                        }

                        VStack(spacing: Theme.spacingSM) {
                            ForEach(DayOfWeek.allCases) { day in
                                weekEditorDayCard(day)
                            }
                        }
                    }
                    .padding(Theme.spacingMD)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showWeekEditor = false
                    }
                }
            }
        }
        .sheet(isPresented: $showWeekDayEditor) {
            weekDayEditorSheet
        }
    }

    private func weekEditorDayCard(_ day: DayOfWeek) -> some View {
        let isToday = day == DayOfWeek.today
        let assignment = viewModel.assignment(for: day)
        let formulas = viewModel.formulasForDay(day)

        return Button {
            openWeekDayEditor(for: day)
        } label: {
            HStack(alignment: .top, spacing: Theme.spacingMD) {
                VStack(alignment: .leading, spacing: Theme.spacingXS) {
                    Text(isToday ? "TODAY" : day.shortName.uppercased())
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isToday ? Theme.selectionForeground : Theme.textTertiary)
                        .padding(.horizontal, Theme.spacingSM)
                        .padding(.vertical, 6)
                        .background(isToday ? Theme.selectionBackground : Theme.backgroundTertiary)
                        .clipShape(Capsule())

                    Text(assignment.resolvedTitle)
                        .font(Theme.body1())
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)

                    Text(assignment.details.isEmpty ? "Add a description or focus for this day." : assignment.details)
                        .font(.system(size: 12))
                        .foregroundColor(assignment.details.isEmpty ? Theme.textTertiary : Theme.textSecondary)
                        .lineSpacing(2)
                        .lineLimit(3)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: Theme.spacingXS) {
                    if formulas.isEmpty {
                        Text("No formulas")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.textTertiary)
                    } else {
                        ForEach(formulas.prefix(2)) { formula in
                            Text("\(formula.emoji) \(formula.name)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                        }

                        if formulas.count > 2 {
                            Text("+\(formulas.count - 2) more")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.textTertiary)
                        .padding(.top, Theme.spacingXS)
                }
            }
            .padding(Theme.spacingMD)
            .background(Theme.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMD)
                    .stroke(isToday ? Theme.accent.opacity(0.22) : Theme.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var weekDayEditorSheet: some View {
        NavigationView {
            ZStack {
                Theme.backgroundPrimary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                            Text("Edit \(editingWeekDay.displayName)")
                                .font(Theme.heading2())
                                .foregroundColor(Theme.textPrimary)

                            Text("Name the day, describe it, and decide which full formulas belong on it.")
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)
                        }

                        selectedFormulasPreview

                        editorField(title: "DAY NAME") {
                            TextField(editingWeekDay.displayName, text: $weekDayTitle, prompt: Text(editingWeekDay.displayName).foregroundColor(Theme.textTertiary))
                                .font(Theme.body1())
                                .foregroundColor(Theme.textPrimary)
                                .padding(Theme.spacingMD)
                                .background(Theme.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                        }

                        editorField(title: "DESCRIPTION") {
                            ZStack(alignment: .topLeading) {
                                if weekDayDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("How should this day feel? What matters here?")
                                        .font(Theme.body2())
                                        .foregroundColor(Theme.textTertiary)
                                        .padding(.horizontal, Theme.spacingMD)
                                        .padding(.top, 14)
                                }

                                TextEditor(text: $weekDayDetails)
                                    .font(Theme.body2())
                                    .foregroundColor(Theme.textPrimary)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 120)
                                    .padding(Theme.spacingSM)
                            }
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                        }

                        editorField(title: "FORMULAS") {
                            VStack(spacing: Theme.spacingSM) {
                                HStack {
                                    Text("\(selectedFormulaIDs.count) selected")
                                        .font(Theme.caption())
                                        .foregroundColor(Theme.textTertiary)

                                    Spacer()

                                    Button {
                                        beginInlineFormulaCreation()
                                    } label: {
                                        Label("New Formula", systemImage: "plus.circle.fill")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Theme.accent)
                                    }
                                }

                                if viewModel.activeFormulas.isEmpty {
                                    CueCard {
                                        VStack(alignment: .leading, spacing: Theme.spacingSM) {
                                            Text("No full formulas yet.")
                                                .font(Theme.body2())
                                                .foregroundColor(Theme.textPrimary)

                                            Text("Create one here, then assign it to this day.")
                                                .font(Theme.caption())
                                                .foregroundColor(Theme.textTertiary)

                                            Button("Create Formula") {
                                                beginInlineFormulaCreation()
                                            }
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundColor(Theme.accent)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }

                                ForEach(viewModel.activeFormulas) { formula in
                                    Button {
                                        toggleFormulaSelection(formula.id)
                                    } label: {
                                        HStack(spacing: Theme.spacingMD) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 4)
                                                    .fill(formula.blocks.first?.categoryColor ?? Theme.backgroundTertiary)
                                                    .frame(width: 6, height: 28)

                                                Color.clear.frame(width: 6, height: 28)
                                            }

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("\(formula.emoji) \(formula.name)")
                                                    .font(Theme.body2())
                                                    .fontWeight(.medium)
                                                    .foregroundColor(Theme.textPrimary)

                                                Text("\(formula.blockCount) blocks • \(formula.formattedTargetDuration)")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(Theme.textTertiary)
                                            }

                                            Spacer()

                                            Image(systemName: selectedFormulaIDs.contains(formula.id) ? "checkmark.circle.fill" : "circle")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(selectedFormulaIDs.contains(formula.id) ? Theme.accent : Theme.textTertiary)
                                        }
                                        .padding(Theme.spacingMD)
                                        .background(Theme.backgroundCard)
                                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(Theme.spacingMD)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showWeekDayEditor = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveWeekDayEditor()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .sheet(isPresented: $showInlineFormulaCreator, onDismiss: handleInlineFormulaCreatorDismissed) {
            FormulaEditorView(viewModel: viewModel, formula: nil)
        }
    }

    private var selectedFormulasPreview: some View {
        let selectedFormulas = viewModel.activeFormulas.filter { selectedFormulaIDs.contains($0.id) }

        return VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("SELECTED")
                .font(Theme.caption())
                .foregroundColor(Theme.textTertiary)

            if selectedFormulas.isEmpty {
                CueCard {
                    Text("No formulas assigned yet.")
                        .font(Theme.body2())
                        .foregroundColor(Theme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.spacingSM) {
                        ForEach(selectedFormulas) { formula in
                            HStack(spacing: 8) {
                                Text(formula.emoji)
                                Text(formula.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(1)

                                Button {
                                    selectedFormulaIDs.remove(formula.id)
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                            .padding(.horizontal, Theme.spacingSM)
                            .padding(.vertical, 10)
                            .background(Theme.backgroundCard)
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private func editorField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text(title)
                .font(Theme.caption())
                .foregroundColor(Theme.textTertiary)
            content()
        }
    }

    private func openWeekDayEditor(for day: DayOfWeek) {
        let assignment = viewModel.assignment(for: day)
        editingWeekDay = day
        weekDayTitle = assignment.title
        weekDayDetails = assignment.details
        selectedFormulaIDs = Set(assignment.formulaIds)
        showWeekDayEditor = true
    }

    private func toggleFormulaSelection(_ formulaID: UUID) {
        if selectedFormulaIDs.contains(formulaID) {
            selectedFormulaIDs.remove(formulaID)
        } else {
            selectedFormulaIDs.insert(formulaID)
        }
    }

    private func beginInlineFormulaCreation() {
        formulaIDsBeforeInlineCreation = Set(viewModel.activeFormulas.map(\.id))
        viewModel.editingFormula = nil
        viewModel.newFormulaType = .full
        showInlineFormulaCreator = true
    }

    private func handleInlineFormulaCreatorDismissed() {
        let updatedIDs = Set(viewModel.activeFormulas.map(\.id))
        let newIDs = updatedIDs.subtracting(formulaIDsBeforeInlineCreation)
        selectedFormulaIDs.formUnion(newIDs)
    }

    private func saveWeekDayEditor() {
        let orderedIDs = viewModel.activeFormulas
            .map(\.id)
            .filter { selectedFormulaIDs.contains($0) }

        viewModel.updateWeekDay(
            editingWeekDay,
            title: weekDayTitle,
            details: weekDayDetails,
            formulaIds: orderedIDs
        )

        showWeekDayEditor = false
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.heading3())
            .foregroundColor(Theme.textPrimary)
            .padding(.horizontal, Theme.spacingMD)
            .padding(.top, Theme.spacingSM)
    }
    
    private func emptyCard(_ text: String, icon: String) -> some View {
        CueCard {
            HStack {
                Spacer()
                VStack(spacing: Theme.spacingSM) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(Theme.textTertiary)
                    Text(text)
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(.vertical, Theme.spacingLG)
        }
    }
}
