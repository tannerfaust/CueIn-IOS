//
//  RoadblockSheet.swift
//  CueIn
//
//  Roadblock — add task, task now (override), tune into flow.
//

import SwiftUI

struct RoadblockSheet: View {
    @ObservedObject var viewModel: TodayViewModel
    
    @State private var taskNowName: String = ""
    @State private var taskNowDuration: Double = 15
    @State private var taskNowCategory: BlockCategory = .custom
    @State private var showTaskNow: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                Text("Roadblock")
                    .font(Theme.heading2())
                    .foregroundColor(Theme.textPrimary)
                    .padding(.top, Theme.spacingLG)
                
                // Quick Actions
                VStack(spacing: Theme.spacingSM) {
                    // Add task (after current block)
                    Button {
                        viewModel.showRoadblockSheet = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.showAddTaskSheet = true
                        }
                    } label: {
                        actionRow(icon: "plus.circle", title: "Add a Task", subtitle: "Insert after current block", color: Theme.textSecondary)
                    }
                    .buttonStyle(.plain)
                    
                    // Task NOW — override current
                    Button {
                        withAnimation { showTaskNow.toggle() }
                    } label: {
                        actionRow(icon: "bolt.circle.fill", title: "Task Now", subtitle: "Override current block immediately", color: Theme.warning)
                    }
                    .buttonStyle(.plain)
                    
                    if showTaskNow {
                        taskNowForm
                    }
                    
                    // Tune into Flow
                    Button {
                        viewModel.tuneIntoFlow()
                        dismiss()
                    } label: {
                        actionRow(icon: "wind", title: "Tune into Flow", subtitle: "Insert mini-formula to reset focus", color: Theme.success)
                    }
                    .buttonStyle(.plain)
                }
                
                Spacer()
            }
            .padding(.horizontal, Theme.spacingMD)
        }
    }
    
    private func actionRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: Theme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(color)
                .frame(width: 36)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.body1())
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                
                Text(subtitle)
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
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
    
    // MARK: - Task Now Form
    
    private var taskNowForm: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            TextField("What needs to happen right now?", text: $taskNowName)
                .font(Theme.body1())
                .foregroundColor(Theme.textPrimary)
                .padding(Theme.spacingMD)
                .background(Theme.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
            
            HStack {
                Text("\(Int(taskNowDuration))m")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 45)
                
                Slider(value: $taskNowDuration, in: 5...120, step: 5)
                    .tint(Theme.warning)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.spacingSM) {
                    ForEach(BlockCategory.allCases) { cat in
                        Button { taskNowCategory = cat } label: {
                            HStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(cat.color)
                                    .frame(width: 3, height: 12)
                                Text(cat.displayName)
                                    .font(Theme.caption())
                            }
                            .foregroundColor(taskNowCategory == cat ? .white : Theme.textTertiary)
                            .padding(.horizontal, Theme.spacingSM)
                            .padding(.vertical, Theme.spacingXS)
                            .background(taskNowCategory == cat ? Theme.backgroundElevated : Theme.backgroundCard)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            CueButton(title: "Start Now", icon: "bolt.fill") {
                viewModel.addTaskNow(
                    name: taskNowName,
                    duration: taskNowDuration * 60,
                    flowLogic: .blocking,
                    category: taskNowCategory
                )
                dismiss()
            }
            .disabled(taskNowName.isEmpty)
            .opacity(taskNowName.isEmpty ? 0.5 : 1)
        }
        .padding(Theme.spacingSM)
        .background(Theme.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }
}
