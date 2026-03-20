//
//  ProfileView.swift
//  CueIn
//
//  Profile tab — simple stage name, daily target, goals, settings.
//  No text wall — clean, functional.
//

import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var viewModel: ProfileViewModel
    
    @State private var newGoalTitle: String = ""
    @State private var newGoalCategory: BlockCategory? = nil
    @State private var editStageName: String = ""
    @State private var showSettings: Bool = false
    
    init(dataStore: DataStore) {
        _viewModel = StateObject(wrappedValue: ProfileViewModel(dataStore: dataStore))
    }
    
    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    // Header
                    HStack {
                        Text("Profile")
                            .font(Theme.heading1())
                            .foregroundColor(Theme.textPrimary)
                        
                        Spacer()
                        
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 18))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, Theme.spacingMD)
                    .padding(.top, Theme.spacingSM)
                    
                    // Stage name — editable inline
                    stageCard
                        .padding(.horizontal, Theme.spacingMD)
                    
                    // Daily target
                    targetCard
                        .padding(.horizontal, Theme.spacingMD)
                    
                    // Goals
                    goalsSection
                        .padding(.horizontal, Theme.spacingMD)
                }
                .padding(.bottom, Theme.spacingXL)
            }
        }
        .sheet(isPresented: $viewModel.showAddGoal) {
            addGoalSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(dataStore: dataStore)
        }
    }
    
    // MARK: - Stage Card (simple, no text wall)
    
    private var stageCard: some View {
        CueCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("STAGE")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                    
                    if viewModel.isEditingStage {
                        TextField("Stage name", text: $editStageName)
                            .font(Theme.heading2())
                            .foregroundColor(Theme.textPrimary)
                            .onSubmit { viewModel.updateStage(editStageName) }
                    } else {
                        Text(viewModel.profile.stageName)
                            .font(Theme.heading2())
                            .foregroundColor(Theme.textPrimary)
                    }
                }
                
                Spacer()
                
                Button {
                    if viewModel.isEditingStage {
                        viewModel.updateStage(editStageName)
                    } else {
                        editStageName = viewModel.profile.stageName
                        viewModel.isEditingStage = true
                    }
                } label: {
                    Image(systemName: viewModel.isEditingStage ? "checkmark.circle.fill" : "pencil.circle")
                        .font(.system(size: 22))
                        .foregroundColor(viewModel.isEditingStage ? Theme.success : Theme.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Target Card
    
    private var targetCard: some View {
        CueCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAILY TARGET")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                    
                    Text("\(viewModel.profile.dailyTargetHours)h / day")
                        .font(Theme.body1())
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Spacer()
                
                HStack(spacing: Theme.spacingSM) {
                    Button {
                        if viewModel.profile.dailyTargetHours > 4 {
                            viewModel.dataStore.profile.dailyTargetHours -= 1
                        }
                    } label: {
                        Image(systemName: "minus.circle")
                            .font(.system(size: 22))
                            .foregroundColor(Theme.textSecondary)
                    }
                    
                    Text("\(viewModel.profile.dailyTargetHours)")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .frame(width: 30)
                    
                    Button {
                        if viewModel.profile.dailyTargetHours < 20 {
                            viewModel.dataStore.profile.dailyTargetHours += 1
                        }
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 22))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Goals
    
    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack {
                Text("Goals")
                    .font(Theme.heading3())
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Button { viewModel.showAddGoal = true } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(width: 26, height: 26)
                        .background(Color.white)
                        .clipShape(Circle())
                }
            }
            
            if viewModel.profile.goals.isEmpty {
                CueCard {
                    HStack {
                        Spacer()
                        VStack(spacing: Theme.spacingSM) {
                            Image(systemName: "target")
                                .font(.system(size: 24))
                                .foregroundColor(Theme.textTertiary)
                            Text("No goals yet")
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, Theme.spacingLG)
                }
            } else {
                ForEach(Array(viewModel.profile.goals.enumerated()), id: \.element.id) { index, goal in
                    goalRow(goal, index: index)
                }
            }
        }
    }
    
    private func goalRow(_ goal: Goal, index: Int) -> some View {
        HStack(spacing: Theme.spacingMD) {
            Button { viewModel.toggleGoal(at: index) } label: {
                ZStack {
                    Circle()
                        .stroke(goal.isCompleted ? Theme.success : Theme.textTertiary, lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                    if goal.isCompleted {
                        Circle()
                            .fill(Theme.success)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
            }
            .buttonStyle(.plain)
            
            Text(goal.title)
                .font(Theme.body1())
                .fontWeight(.medium)
                .foregroundColor(goal.isCompleted ? Theme.textTertiary : Theme.textPrimary)
                .strikethrough(goal.isCompleted)
            
            Spacer()
            
            if let cat = goal.category {
                RoundedRectangle(cornerRadius: 2)
                    .fill(cat.color)
                    .frame(width: 3, height: 18)
            }
            
            Button { viewModel.deleteGoal(at: index) } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(Theme.spacingMD)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }
    
    // MARK: - Add Goal Sheet
    
    private var addGoalSheet: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                Text("New Goal")
                    .font(Theme.heading2())
                    .foregroundColor(Theme.textPrimary)
                    .padding(.top, Theme.spacingLG)
                
                TextField("Goal title", text: $newGoalTitle)
                    .font(Theme.body1())
                    .foregroundColor(Theme.textPrimary)
                    .padding(Theme.spacingMD)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                
                Text("CATEGORY")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.spacingSM) {
                        Button { newGoalCategory = nil } label: {
                            Text("None")
                                .font(Theme.caption())
                                .foregroundColor(newGoalCategory == nil ? .white : Theme.textTertiary)
                                .padding(.horizontal, Theme.spacingSM)
                                .padding(.vertical, Theme.spacingXS)
                                .background(newGoalCategory == nil ? Theme.backgroundElevated : Theme.backgroundCard)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                        
                        ForEach(BlockCategory.allCases) { cat in
                            Button { newGoalCategory = cat } label: {
                                HStack(spacing: 4) {
                                    RoundedRectangle(cornerRadius: 2)
                                        .fill(cat.color)
                                        .frame(width: 3, height: 12)
                                    Text(cat.displayName)
                                        .font(Theme.caption())
                                }
                                .foregroundColor(newGoalCategory == cat ? .white : Theme.textSecondary)
                                .padding(.horizontal, Theme.spacingSM)
                                .padding(.vertical, Theme.spacingXS)
                                .background(newGoalCategory == cat ? Theme.backgroundElevated : Theme.backgroundCard)
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                
                CueButton(title: "Add Goal", icon: "target") {
                    viewModel.addGoal(title: newGoalTitle, description: "", category: newGoalCategory)
                    newGoalTitle = ""
                    newGoalCategory = nil
                    viewModel.showAddGoal = false
                }
                .disabled(newGoalTitle.isEmpty)
                .opacity(newGoalTitle.isEmpty ? 0.5 : 1)
                
                Spacer()
            }
            .padding(.horizontal, Theme.spacingMD)
        }
    }
}
