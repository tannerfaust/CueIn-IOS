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
    @Published var showAddGoal: Bool = false
    
    init(dataStore: DataStore) {
        self.dataStore = dataStore
    }
    
    var profile: UserProfile {
        get { dataStore.profile }
        set { dataStore.profile = newValue }
    }
    
    func addGoal(title: String, description: String, category: BlockCategory?) {
        let goal = Goal(title: title, description: description, category: category)
        dataStore.profile.goals.append(goal)
    }
    
    func toggleGoal(at index: Int) {
        guard index < dataStore.profile.goals.count else { return }
        dataStore.profile.goals[index].isCompleted.toggle()
    }
    
    func deleteGoal(at index: Int) {
        guard index < dataStore.profile.goals.count else { return }
        dataStore.profile.goals.remove(at: index)
    }
    
    func updateStage(_ name: String) {
        dataStore.profile.stageName = name
        isEditingStage = false
    }
}
