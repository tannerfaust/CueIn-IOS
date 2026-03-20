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
    
    init(dataStore: DataStore) {
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
                                .foregroundColor(.black)
                                .frame(width: 32, height: 32)
                                .background(Color.white)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, Theme.spacingMD)
                    .padding(.top, Theme.spacingSM)
                    
                    // Week Schedule — EDITABLE
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
    }
    
    // MARK: - Week Schedule Section (editable)
    
    private var weekScheduleSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack {
                Text("Week Schedule")
                    .font(Theme.heading3())
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Text("Tap day to assign")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.spacingSM) {
                    ForEach(DayOfWeek.allCases) { day in
                        weekDayColumn(day)
                    }
                }
            }
        }
    }
    
    private func weekDayColumn(_ day: DayOfWeek) -> some View {
        let isToday = day == DayOfWeek.today
        let formulas = viewModel.formulasForDay(day)
        
        return Menu {
            // Assign formulas to this day
            ForEach(viewModel.allFormulas.filter({ $0.type == .full })) { formula in
                let isAssigned = formulas.contains(where: { $0.id == formula.id })
                Button {
                    if isAssigned {
                        viewModel.removeFormula(formula.id, from: day)
                    } else {
                        viewModel.assignFormula(formula, to: day)
                    }
                } label: {
                    Label(
                        "\(formula.emoji) \(formula.name)",
                        systemImage: isAssigned ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
        } label: {
            VStack(spacing: Theme.spacingXS) {
                Text(day.shortName)
                    .font(Theme.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(isToday ? .white : Theme.textSecondary)
                
                if formulas.isEmpty {
                    RoundedRectangle(cornerRadius: Theme.radiusSM)
                        .fill(Theme.backgroundTertiary)
                        .frame(width: 72, height: 52)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textTertiary)
                        )
                } else {
                    VStack(spacing: 2) {
                        ForEach(formulas.prefix(2)) { formula in
                            Text("\(formula.emoji) \(formula.name)")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)
                                .frame(width: 72)
                        }
                        if formulas.count > 2 {
                            Text("+\(formulas.count - 2)")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    .frame(width: 72, height: 52)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                }
            }
            .padding(.vertical, Theme.spacingXS)
            .background(
                RoundedRectangle(cornerRadius: Theme.radiusSM)
                    .fill(isToday ? Theme.backgroundElevated : Color.clear)
            )
        }
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
