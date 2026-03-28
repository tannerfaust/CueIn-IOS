//
//  CueBlockRow.swift
//  CueIn
//
//  Today block row with the original card styling and menu actions.
//

import SwiftUI

struct CueBlockRow: View {
    let block: Block
    let isActive: Bool
    var isExecuting: Bool = false
    var isAwaitingExecution: Bool = false
    var isPaused: Bool = false
    var onCheck: (() -> Void)? = nil
    var onExecutionPlay: (() -> Void)? = nil
    var onPlayNow: (() -> Void)? = nil
    var onCommitmentTap: (() -> Void)? = nil
    var onPauseToggle: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var dragItemProvider: (() -> NSItemProvider)? = nil
    var showRealTime: Bool = false
    var realTimeLabel: String? = nil
    var showCommitmentButton: Bool = false

    private var showsMenu: Bool {
        onPlayNow != nil || onPauseToggle != nil || onEdit != nil || onDuplicate != nil || onDelete != nil
    }

    private var showsExecutionPlayButton: Bool {
        onExecutionPlay != nil && !isExecuting && !block.isChecked
    }

    private var showsCommitmentButton: Bool {
        showCommitmentButton && block.isChecked && onCommitmentTap != nil
    }

    var body: some View {
        HStack(spacing: Theme.spacingMD) {
            Button(action: { onCheck?() }) {
                ZStack {
                    Circle()
                        .stroke(block.isChecked ? Theme.success : Theme.textTertiary, lineWidth: 1.5)
                        .frame(width: 24, height: 24)

                    if block.isChecked {
                        Circle()
                            .fill(Theme.success)
                            .frame(width: 24, height: 24)

                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
            }
            .frame(width: 40, height: 40)
            .contentShape(Rectangle())
            .buttonStyle(.plain)

            RoundedRectangle(cornerRadius: 2)
                .fill(block.categoryColor)
                .frame(width: 3, height: isActive ? 44 : 32)
                .shadow(color: isActive ? block.categoryColor.opacity(0.6) : .clear, radius: 8, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.5), value: isActive)

            VStack(alignment: .leading, spacing: 3) {
                Text(block.name)
                    .font(Theme.body1())
                    .fontWeight(isActive ? .semibold : .medium)
                    .foregroundColor(block.isChecked ? Theme.textTertiary : Theme.textPrimary)
                    .strikethrough(block.isChecked)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                HStack(spacing: Theme.spacingSM) {
                    Text(block.formattedDuration)
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)

                    Image(systemName: block.flowLogic == .flowing ? "wind" : "lock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.textTertiary)

                    if showRealTime, let timeLabel = realTimeLabel {
                        Text(timeLabel)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Theme.backgroundTertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    }
                }

                if block.hasMiniFormula || isPaused || isAwaitingExecution {
                    HStack(spacing: Theme.spacingSM) {
                        if block.hasMiniFormula {
                            miniProgressBadge
                        }

                        if isAwaitingExecution {
                            awaitingExecutionBadge
                        }

                        if isPaused && !isActive {
                            pausedMetaBadge
                        }
                    }
                }
            }
            .layoutPriority(1)

            Spacer()

            if isActive && !block.isChecked && !isAwaitingExecution {
                if isPaused {
                    pausedIndicator
                } else {
                    circularTimer
                }
            }

            if showsExecutionPlayButton, let onExecutionPlay {
                Button(action: onExecutionPlay) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.black)
                        .frame(width: 30, height: 30)
                        .background(block.categoryColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if showsCommitmentButton, let onCommitmentTap {
                Button(action: onCommitmentTap) {
                    HStack(spacing: 4) {
                        Image(systemName: block.commitmentRating == nil ? "star" : "star.fill")
                            .font(.system(size: 11, weight: .semibold))
                        Text(commitmentLabel)
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    }
                    .foregroundColor(block.commitmentRating == nil ? Theme.textSecondary : Theme.warning)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Theme.backgroundCard)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            if let dragItemProvider {
                Image(systemName: "line.3.horizontal")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
                    .onDrag {
                        dragItemProvider()
                    }
            }

            if showsMenu {
                Menu {
                    if let onPlayNow {
                        Button {
                            onPlayNow()
                        } label: {
                            Label("Play This Block", systemImage: "play.circle")
                        }
                    }

                    if let onCheck {
                        Button {
                            onCheck()
                        } label: {
                            Label(
                                block.isChecked ? "Uncheck" : "Check Off",
                                systemImage: block.isChecked ? "arrow.uturn.backward.circle" : "checkmark.circle"
                            )
                        }
                    }

                    if let onPauseToggle {
                        Button {
                            onPauseToggle()
                        } label: {
                            Label(
                                isPaused ? "Resume Block" : "Pause Block",
                                systemImage: isPaused ? "play.circle" : "pause.circle"
                            )
                        }
                    }

                    if let onEdit {
                        Button {
                            onEdit()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                    }

                    if let onDuplicate {
                        Button {
                            onDuplicate()
                        } label: {
                            Label("Copy", systemImage: "plus.square.on.square")
                        }
                    }

                    if let onDelete {
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textTertiary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacingMD)
        .background(blockBackground)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .stroke(
                    isActive && !block.isChecked ? block.categoryColor.opacity(0.2) : Color.clear,
                    lineWidth: 1
                )
        )
        .shadow(
            color: isActive && !block.isChecked ? block.categoryColor.opacity(0.08) : .clear,
            radius: 12, x: 0, y: 4
        )
    }

    private var pausedIndicator: some View {
        HStack(spacing: 5) {
            Image(systemName: "pause.fill")
                .font(.system(size: 9, weight: .bold))

            Text("Paused")
                .font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(Theme.warning)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Theme.warning.opacity(0.12))
        .clipShape(Capsule())
    }

    private var miniProgressBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "square.stack.3d.up")
                .font(.system(size: 10, weight: .semibold))

            Text("\(block.completedMiniTaskCount)/\(block.miniTaskCount)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .foregroundColor(Theme.textSecondary)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var pausedMetaBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "pause.fill")
                .font(.system(size: 9, weight: .bold))

            Text("Paused")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(Theme.warning)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var awaitingExecutionBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.tap")
                .font(.system(size: 9, weight: .semibold))

            Text("Tap Play")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundColor(Theme.textSecondary)
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var commitmentLabel: String {
        guard let commitmentRating = block.commitmentRating else { return "Rate" }
        return "\(commitmentRating)/5"
    }

    private var circularTimer: some View {
        let progress = block.duration > 0 ? min(1, block.elapsedTime / block.duration) : 0
        let isOverrun = block.elapsedTime > block.duration
        let color: Color = isOverrun ? Theme.error : block.categoryColor

        return ZStack {
            Circle()
                .stroke(Theme.backgroundTertiary, lineWidth: 3)
                .frame(width: 40, height: 40)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            Circle()
                .fill(color.opacity(0.08))
                .frame(width: 34, height: 34)

            Text(block.formattedRemaining)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(isOverrun ? Theme.error : Theme.textPrimary)
        }
    }

    private var blockBackground: some View {
        Group {
            if isExecuting && !block.isChecked {
                LinearGradient(
                    colors: [
                        block.categoryColor.opacity(0.1),
                        Theme.backgroundElevated
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else if isActive && !block.isChecked {
                LinearGradient(
                    colors: [
                        block.categoryColor.opacity(0.06),
                        Theme.backgroundElevated
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            } else if block.isChecked {
                Theme.backgroundSecondary.opacity(0.6)
            } else {
                Theme.backgroundSecondary
            }
        }
    }
}
