//
//  LabViewModel.swift
//  CueIn
//
//  State management for the Lab tab.
//

import Foundation
import Combine

class LabViewModel: ObservableObject {
    @Published var dataStore: DataStore
    @Published var showFormulaEditor: Bool = false
    @Published var editingFormula: Formula? = nil
    @Published var newFormulaType: FormulaType = .full
    
    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }
    
    var activeFormulas: [Formula] {
        dataStore.formulas.filter { $0.status == .active && $0.type == .full }
    }
    
    var miniFormulas: [Formula] {
        dataStore.formulas.filter { $0.type == .mini }
    }
    
    var allFormulas: [Formula] {
        dataStore.formulas
    }

    var weekAssignments: [DayAssignment] {
        DayOfWeek.allCases.compactMap { dataStore.weekSchedule.assignment(for: $0) }
    }
    
    func formulasForDay(_ day: DayOfWeek) -> [Formula] {
        let ids = dataStore.weekSchedule.formulaIds(for: day)
        return ids.compactMap { id in dataStore.formulas.first { $0.id == id } }
    }

    func assignment(for day: DayOfWeek) -> DayAssignment {
        dataStore.weekSchedule.assignment(for: day) ?? DayAssignment(day: day)
    }
    
    func assignFormula(_ formula: Formula, to day: DayOfWeek) {
        var ids = dataStore.weekSchedule.formulaIds(for: day)
        if !ids.contains(formula.id) {
            ids.append(formula.id)
            dataStore.weekSchedule.setFormulaIds(ids, for: day)
        }
    }
    
    func removeFormula(_ formulaId: UUID, from day: DayOfWeek) {
        var ids = dataStore.weekSchedule.formulaIds(for: day)
        ids.removeAll { $0 == formulaId }
        dataStore.weekSchedule.setFormulaIds(ids, for: day)
    }

    func updateWeekDay(
        _ day: DayOfWeek,
        title: String,
        details: String,
        formulaIds: [UUID]
    ) {
        dataStore.weekSchedule.updateAssignment(
            for: day,
            title: title,
            details: details,
            formulaIds: formulaIds
        )
    }
    
    func editFormula(_ formula: Formula) {
        editingFormula = formula
        showFormulaEditor = true
    }
    
    func saveFormula(_ formula: Formula) {
        if dataStore.formulas.contains(where: { $0.id == formula.id }) {
            dataStore.updateFormula(formula)
        } else {
            dataStore.addFormula(formula)
        }
    }
    
    func deleteFormula(_ id: UUID) {
        dataStore.deleteFormula(id)
    }
}
