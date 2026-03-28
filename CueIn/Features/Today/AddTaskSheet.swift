//
//  AddTaskSheet.swift
//  CueIn
//
//  Add task — proper toggle for duration, time-of-day picker.
//

import SwiftUI

struct AddTaskSheet: View {
    @ObservedObject var viewModel: TodayViewModel
    
    @State private var taskName: String = ""
    @State private var durationMinutes: Double = 30
    @State private var hasSpecifiedDuration: Bool = true
    @State private var hasSpecifiedTime: Bool = false
    @State private var scheduledTime: Date = Date()
    @State private var selectedFlowLogic: FlowLogic = .flowing
    @State private var selectedCategory: BlockCategory = .custom
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()
            
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    Text("Add a Task")
                        .font(Theme.heading2())
                        .foregroundColor(Theme.textPrimary)
                        .padding(.top, Theme.spacingLG)
                    
                    // 1 — Name
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        sectionLabel("1. Task Name")
                        
                        TextField("What needs to happen?", text: $taskName)
                            .font(Theme.body1())
                            .foregroundColor(Theme.textPrimary)
                            .padding(Theme.spacingMD)
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                    }
                    
                    // 2 — Duration with proper toggle
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        sectionLabel("2. Duration")
                        
                        // Toggle: specified vs unspecified
                        HStack(spacing: Theme.spacingMD) {
                            durationOption(
                                icon: "clock",
                                label: "Set duration",
                                isSelected: hasSpecifiedDuration
                            ) {
                                withAnimation { hasSpecifiedDuration = true }
                            }
                            
                            durationOption(
                                icon: "infinity",
                                label: "Until done",
                                isSelected: !hasSpecifiedDuration
                            ) {
                                withAnimation { hasSpecifiedDuration = false }
                            }
                        }
                        
                        if hasSpecifiedDuration {
                            VStack(spacing: Theme.spacingXS) {
                                // Prominent duration display
                                Text("\(Int(durationMinutes)) min")
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.accent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, Theme.spacingSM)
                                
                                Slider(value: $durationMinutes, in: 5...240, step: 5)
                                    .tint(Theme.accent)
                                
                                HStack {
                                    Text("5m")
                                        .font(Theme.caption())
                                        .foregroundColor(Theme.textTertiary)
                                    Spacer()
                                    Text("4h")
                                        .font(Theme.caption())
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                            .padding(Theme.spacingMD)
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                        } else {
                            Text("Block stays active until you check it off")
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)
                                .padding(Theme.spacingMD)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Theme.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                        }
                    }
                    
                    // 3 — Time (optional)
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        sectionLabel("3. Scheduled Time (optional)")
                        
                        Toggle(isOn: $hasSpecifiedTime.animation()) {
                            HStack(spacing: Theme.spacingSM) {
                                Image(systemName: "clock.badge")
                                    .foregroundColor(Theme.textSecondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Set specific time")
                                        .font(Theme.body2())
                                        .foregroundColor(Theme.textPrimary)
                                    Text(hasSpecifiedTime ? "Block will be placed at this time" : "App places it after current block")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.textTertiary)
                                }
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
                        .padding(Theme.spacingMD)
                        .background(Theme.backgroundCard)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                        
                        if hasSpecifiedTime {
                            DatePicker(
                                "Time",
                                selection: $scheduledTime,
                                displayedComponents: .hourAndMinute
                            )
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .frame(height: 140)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                        }
                    }
                    
                    // 4 — Category
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        sectionLabel("4. Category")
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Theme.spacingSM) {
                                ForEach(BlockCategory.allCases) { cat in
                                    Button(action: { selectedCategory = cat }) {
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
                                        .foregroundColor(selectedCategory == cat ? Theme.selectionForeground : Theme.textSecondary)
                                        .background(selectedCategory == cat ? Theme.selectionBackground : Theme.backgroundCard)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(selectedCategory == cat ? cat.color.opacity(0.5) : Color.clear, lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    
                    // 5 — Flow Logic with descriptions
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        sectionLabel("5. Flow Logic")
                        
                        ForEach(FlowLogic.allCases) { logic in
                            Button(action: { selectedFlowLogic = logic }) {
                                HStack {
                                    Image(systemName: selectedFlowLogic == logic ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedFlowLogic == logic ? Theme.selectionForeground : Theme.textTertiary)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 4) {
                                            Image(systemName: logic == .flowing ? "wind" : "lock.fill")
                                                .font(.system(size: 10))
                                            Text(logic.displayName)
                                                .font(Theme.body2())
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(Theme.textPrimary)
                                        
                                        Text(logic == .flowing
                                             ? "Auto-advances when time ends"
                                             : "Stays until you check it off")
                                            .font(.system(size: 11))
                                            .foregroundColor(Theme.textTertiary)
                                    }
                                    
                                    Spacer()
                                }
                                .padding(Theme.spacingMD)
                                .background(
                                    selectedFlowLogic == logic
                                    ? Theme.selectionBackground
                                    : Theme.backgroundCard
                                )
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    CueButton(title: "Add Task", icon: "plus") {
                        let duration = hasSpecifiedDuration ? durationMinutes * 60 : 3600
                        let time = hasSpecifiedTime ? scheduledTime : nil
                        viewModel.addTask(
                            name: taskName,
                            duration: duration,
                            flowLogic: selectedFlowLogic,
                            category: selectedCategory,
                            scheduledTime: time
                        )
                        dismiss()
                    }
                    .opacity(taskName.isEmpty ? 0.5 : 1)
                    .disabled(taskName.isEmpty)
                }
                .padding(.horizontal, Theme.spacingMD)
                .padding(.bottom, Theme.spacingXL)
            }
        }
    }
    
    // MARK: - Helpers
    
    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(Theme.caption())
            .fontWeight(.semibold)
            .foregroundColor(Theme.textSecondary)
            .textCase(.uppercase)
    }
    
    private func durationOption(icon: String, label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Theme.spacingSM) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(Theme.caption())
                    .fontWeight(.medium)
            }
            .frame(maxWidth: .infinity)
            .padding(Theme.spacingMD)
            .foregroundColor(isSelected ? Theme.selectionForeground : Theme.textTertiary)
            .background(isSelected ? Theme.selectionBackground : Theme.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusMD)
                    .stroke(isSelected ? Theme.accent.opacity(0.16) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
