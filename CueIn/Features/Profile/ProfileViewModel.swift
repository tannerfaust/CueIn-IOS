//
//  ProfileViewModel.swift
//  CueIn
//
//  State management for the Profile tab.
//

import Foundation
import Combine

class ProfileViewModel: ObservableObject {
    @Published var dataStore: DataStore
    @Published var isEditingStage: Bool = false
    @Published var showSurgeEditor: Bool = false
    @Published var editingSurge: Surge? = nil

    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }

    var profile: UserProfile {
        get { dataStore.profile }
        set { dataStore.profile = newValue }
    }

    var sortedSurges: [Surge] {
        let today = Date()
        return profile.surges.sorted { lhs, rhs in
            let lhsActive = lhs.isActive(on: today)
            let rhsActive = rhs.isActive(on: today)
            if lhsActive != rhsActive {
                return lhsActive && !rhsActive
            }

            let lhsStarted = lhs.hasStarted(on: today)
            let rhsStarted = rhs.hasStarted(on: today)
            if lhsStarted != rhsStarted {
                return lhsStarted && !rhsStarted
            }

            if lhs.startDate != rhs.startDate {
                return lhs.startDate < rhs.startDate
            }

            return lhs.createdAt > rhs.createdAt
        }
    }

    func updateStage(_ name: String) {
        dataStore.profile.stageName = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Getting Started" : name
        isEditingStage = false
    }

    func startCreatingSurge() {
        editingSurge = nil
        showSurgeEditor = true
    }

    func startEditingSurge(_ surge: Surge) {
        editingSurge = surge
        showSurgeEditor = true
    }

    func saveSurge(_ surge: Surge) {
        if let index = dataStore.profile.surges.firstIndex(where: { $0.id == surge.id }) {
            dataStore.profile.surges[index] = surge
        } else {
            dataStore.profile.surges.append(surge)
        }
        showSurgeEditor = false
        editingSurge = nil
    }

    func deleteSurge(_ surge: Surge) {
        dataStore.profile.surges.removeAll { $0.id == surge.id }
        if editingSurge?.id == surge.id {
            editingSurge = nil
        }
    }
}
