//
//  BlockRowView.swift
//  CueIn
//
//  Block row used in the formula editor with swipe actions.
//

import SwiftUI

struct BlockRowView: View {
    let block: Block
    var showDuration: Bool = true
    var onTap: (() -> Void)? = nil
    var onEdit: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var dragItemProvider: (() -> NSItemProvider)? = nil
    @Binding var activeSwipeBlockID: UUID?
    var isDragging: Bool = false

    @State private var swipeTranslation: CGFloat = 0

    private let actionWidth: CGFloat = 78

    private struct SwipeAction: Identifiable {
        let id = UUID()
        let title: String
        let systemImage: String
        let tint: Color
        let foreground: Color
        let action: () -> Void
    }

    private var swipeActions: [SwipeAction] {
        var actions: [SwipeAction] = []

        if let onEdit {
            actions.append(
                SwipeAction(
                    title: "Edit",
                    systemImage: "pencil",
                    tint: Theme.info,
                    foreground: .black,
                    action: onEdit
                )
            )
        }

        if let onDuplicate {
            actions.append(
                SwipeAction(
                    title: "Copy",
                    systemImage: "plus.square.on.square",
                    tint: Theme.warning,
                    foreground: .black,
                    action: onDuplicate
                )
            )
        }

        if let onDelete {
            actions.append(
                SwipeAction(
                    title: "Delete",
                    systemImage: "trash",
                    tint: Theme.error,
                    foreground: .white,
                    action: onDelete
                )
            )
        }

        return actions
    }

    private var totalSwipeWidth: CGFloat {
        CGFloat(swipeActions.count) * actionWidth
    }

    private var isSwipeOpen: Bool {
        activeSwipeBlockID == block.id
    }

    private var currentOffset: CGFloat {
        let baseOffset = isSwipeOpen ? -totalSwipeWidth : 0
        return max(-totalSwipeWidth, min(0, baseOffset + swipeTranslation))
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if !swipeActions.isEmpty {
                HStack(spacing: 0) {
                    ForEach(swipeActions) { action in
                        swipeActionButton(action)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            rowSurface
                .offset(x: currentOffset)
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
        // Keep horizontal swipe actions responsive without hijacking the parent
        // ScrollView's vertical pan gesture.
        .simultaneousGesture(swipeGesture)
        .onChange(of: activeSwipeBlockID) { newValue in
            if newValue != block.id {
                swipeTranslation = 0
            }
        }
    }

    private var rowSurface: some View {
        HStack(spacing: Theme.spacingMD) {
            RoundedRectangle(cornerRadius: 2)
                .fill(block.categoryColor)
                .frame(width: 4, height: 40)

            HStack(spacing: Theme.spacingMD) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(block.name)
                        .font(Theme.body1())
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)

                    HStack(spacing: Theme.spacingSM) {
                        CueChip(label: block.category.displayName, color: block.categoryColor, icon: block.category.icon)

                        if !block.subcategory.isEmpty {
                            CueChip(label: block.subcategory, color: Theme.textSecondary)
                        }

                        if block.hasMiniFormula {
                            CueChip(label: "Mini", color: Theme.info, icon: "square.stack.3d.up")
                        }
                    }
                }

                Spacer()

                if showDuration {
                    Text(block.formattedDuration)
                        .font(Theme.mono())
                        .foregroundColor(Theme.textSecondary)
                }

                Group {
                    if let dragItemProvider {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textTertiary)
                            .contentShape(Rectangle())
                            .onDrag {
                                dragItemProvider()
                            }
                    } else {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }
        }
        .padding(Theme.spacingMD)
        .background(Theme.backgroundSecondary)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .stroke(isDragging ? block.categoryColor.opacity(0.35) : Color.clear, lineWidth: 1)
        )
        .opacity(isDragging ? 0.72 : 1)
        .scaleEffect(isDragging ? 0.98 : 1)
        .contentShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
        .onTapGesture {
            if isSwipeOpen {
                closeSwipe()
            } else {
                onTap?()
            }
        }
    }

    private func swipeActionButton(_ swipeAction: SwipeAction) -> some View {
        Button {
            closeSwipe()
            swipeAction.action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: swipeAction.systemImage)
                    .font(.system(size: 14, weight: .semibold))
                Text(swipeAction.title)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundColor(swipeAction.foreground)
            .frame(width: actionWidth)
            .frame(maxHeight: .infinity)
            .background(swipeAction.tint)
        }
        .buttonStyle(.plain)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                guard totalSwipeWidth > 0 else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else { return }

                if activeSwipeBlockID != block.id && value.translation.width < 0 {
                    activeSwipeBlockID = block.id
                }

                swipeTranslation = value.translation.width
            }
            .onEnded { value in
                guard totalSwipeWidth > 0 else { return }
                guard abs(value.translation.width) > abs(value.translation.height) else {
                    swipeTranslation = 0
                    return
                }

                let projectedOffset = (isSwipeOpen ? -totalSwipeWidth : 0) + value.translation.width
                let shouldOpen = projectedOffset < (totalSwipeWidth * -0.4)

                withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
                    activeSwipeBlockID = shouldOpen ? block.id : nil
                    swipeTranslation = 0
                }
            }
    }

    private func closeSwipe() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.88)) {
            activeSwipeBlockID = nil
            swipeTranslation = 0
        }
    }
}
