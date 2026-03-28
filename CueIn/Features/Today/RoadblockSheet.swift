//
//  RoadblockSheet.swift
//  CueIn
//
//  Roadblock — add task, task now, tune into flow, forgotten-formula recovery.
//

import SwiftUI

struct RoadblockSheet: View {
    @ObservedObject var viewModel: TodayViewModel

    @State private var taskNowName: String = ""
    @State private var taskNowDuration: Double = 15
    @State private var taskNowCategory: BlockCategory = .custom
    @State private var showTaskNow: Bool = false

    @State private var showForgotRecovery: Bool = false
    @State private var selectedForgotOption: ForgotFollowOption = .mostly
    @State private var continueTodayFormula: Bool = true

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Theme.spacingLG) {
                    Text("Roadblock")
                        .font(Theme.heading2())
                        .foregroundColor(Theme.textPrimary)
                        .padding(.top, Theme.spacingLG)

                    VStack(spacing: Theme.spacingSM) {
                        Button {
                            viewModel.showRoadblockSheet = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                viewModel.showAddTaskSheet = true
                            }
                        } label: {
                            actionRow(
                                icon: "plus.circle",
                                title: "Add a Task",
                                subtitle: "Insert after current block",
                                color: Theme.textSecondary
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            viewModel.toggleCurrentBlockPause()
                            dismiss()
                        } label: {
                            actionRow(
                                icon: viewModel.engine.isCurrentBlockPaused ? "play.circle.fill" : "pause.circle.fill",
                                title: viewModel.engine.isCurrentBlockPaused ? "Resume Current Block" : "Pause Current Block",
                                subtitle: viewModel.engine.isCurrentBlockPaused
                                    ? "Resume this block and shrink later tasks to catch up"
                                    : "Formula time keeps running; later tasks will be recalibrated when you resume",
                                color: Theme.warning
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation { showTaskNow.toggle() }
                        } label: {
                            actionRow(
                                icon: "bolt.circle.fill",
                                title: "Task Now",
                                subtitle: "Pause current block and resume it after",
                                color: Theme.warning
                            )
                        }
                        .buttonStyle(.plain)

                        if showTaskNow {
                            taskNowForm
                        }

                        Button {
                            withAnimation { showForgotRecovery.toggle() }
                        } label: {
                            actionRow(
                                icon: "clock.badge.questionmark",
                                title: "I Forgot About It",
                                subtitle: "Catch the formula up based on how closely you followed it",
                                color: Theme.info
                            )
                        }
                        .buttonStyle(.plain)

                        if showForgotRecovery {
                            forgotRecoveryForm
                        }

                        Button {
                            viewModel.tuneIntoFlow()
                            dismiss()
                        } label: {
                            actionRow(
                                icon: "wind",
                                title: "Tune into Flow",
                                subtitle: "Insert mini-formula to reset focus",
                                color: Theme.success
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, Theme.spacingMD)
                .padding(.bottom, Theme.spacingXL)
            }
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
                    .foregroundColor(Theme.accent)
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
                            .foregroundColor(taskNowCategory == cat ? Theme.selectionForeground : Theme.textTertiary)
                            .padding(.horizontal, Theme.spacingSM)
                            .padding(.vertical, Theme.spacingXS)
                            .background(taskNowCategory == cat ? Theme.selectionBackground : Theme.backgroundCard)
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

    private var forgotRecoveryForm: some View {
        VStack(alignment: .leading, spacing: Theme.spacingMD) {
            VStack(alignment: .leading, spacing: 4) {
                Text("How close did you follow the formula?")
                    .font(Theme.body1())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textPrimary)

                Text("We’ll auto-check the part you likely followed, move those blocks into the done section, and reset the rest.")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
            }

            VStack(spacing: Theme.spacingSM) {
                ForEach(ForgotFollowOption.allCases) { option in
                    Button {
                        selectedForgotOption = option
                    } label: {
                        HStack(spacing: Theme.spacingSM) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(Theme.body2())
                                    .fontWeight(.semibold)
                                    .foregroundColor(
                                        selectedForgotOption == option
                                        ? Theme.selectionForeground
                                        : Theme.textPrimary
                                    )

                                Text(option.subtitle)
                                    .font(.system(size: 11))
                                    .foregroundColor(
                                        selectedForgotOption == option
                                        ? Theme.selectionForeground.opacity(0.8)
                                        : Theme.textTertiary
                                    )
                            }

                            Spacer()

                            Text(option.percentLabel)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(
                                    selectedForgotOption == option
                                    ? Theme.selectionForeground
                                    : Theme.textSecondary
                                )
                        }
                        .padding(Theme.spacingMD)
                        .background(
                            selectedForgotOption == option
                            ? Theme.selectionBackground
                            : Theme.backgroundCard
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                    }
                    .buttonStyle(.plain)
                }
            }

            Toggle(isOn: $continueTodayFormula) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Continue today’s formula")
                        .font(Theme.body2())
                        .foregroundColor(Theme.textPrimary)

                    Text("If off, the formula gets updated and paused so you can come back later.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textTertiary)
                }
            }
            .tint(Theme.accent)

            CueButton(title: "Recover Formula", icon: "wand.and.stars") {
                viewModel.recoverForgottenFormula(
                    followRatio: selectedForgotOption.ratio,
                    continueTodayFormula: continueTodayFormula
                )
                dismiss()
            }
        }
        .padding(Theme.spacingSM)
        .background(Theme.backgroundTertiary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }
}

private enum ForgotFollowOption: CaseIterable, Identifiable {
    case exactly
    case mostly
    case half
    case barely
    case none

    var id: String { title }

    var ratio: Double {
        switch self {
        case .exactly: return 1.0
        case .mostly: return 0.75
        case .half: return 0.5
        case .barely: return 0.25
        case .none: return 0.0
        }
    }

    var title: String {
        switch self {
        case .exactly: return "Almost exactly"
        case .mostly: return "Mostly followed it"
        case .half: return "About half"
        case .barely: return "Barely followed it"
        case .none: return "Didn’t follow it"
        }
    }

    var subtitle: String {
        switch self {
        case .exactly: return "Treat most of the passed formula time as completed."
        case .mostly: return "Catch up a solid part of the schedule."
        case .half: return "Split the passed time between done and not done."
        case .barely: return "Only credit a small part of the missed schedule."
        case .none: return "Keep the time loss, but don’t auto-complete anything."
        }
    }

    var percentLabel: String {
        "\(Int((ratio * 100).rounded()))%"
    }
}
