//
//  CueBlockRow.swift
//  CueIn
//
//  Block row — artistic design with circular timer fill,
//  category accent glow, depth layers, and working ⋯ menu.
//

import SwiftUI

struct CueBlockRow: View {
    let block: Block
    let isActive: Bool
    var onCheck: (() -> Void)? = nil
    var onMenu: (() -> Void)? = nil
    var showRealTime: Bool = false
    var realTimeLabel: String? = nil
    
    var body: some View {
        HStack(spacing: Theme.spacingMD) {
            // Checkbox
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
            .buttonStyle(.plain)
            
            // Category color bar — glowing when active
            RoundedRectangle(cornerRadius: 2)
                .fill(block.categoryColor)
                .frame(width: 3, height: isActive ? 44 : 32)
                .shadow(color: isActive ? block.categoryColor.opacity(0.6) : .clear, radius: 8, x: 0, y: 0)
                .animation(.easeInOut(duration: 0.5), value: isActive)
            
            // Name + details
            VStack(alignment: .leading, spacing: 3) {
                Text(block.name)
                    .font(Theme.body1())
                    .fontWeight(isActive ? .semibold : .medium)
                    .foregroundColor(block.isChecked ? Theme.textTertiary : Theme.textPrimary)
                    .strikethrough(block.isChecked)
                
                HStack(spacing: Theme.spacingSM) {
                    // Duration
                    Text(block.formattedDuration)
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                    
                    // Flow logic icon
                    Image(systemName: block.flowLogic == .flowing ? "wind" : "lock.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Theme.textTertiary)
                    
                    // Real time label (optional)
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
            }
            
            Spacer()
            
            // Circular timer — real fill animation (active block only)
            if isActive && !block.isChecked {
                circularTimer
            }
            
            // ⋯ menu — WORKING
            Menu {
                if !block.isChecked {
                    Button {
                        onCheck?()
                    } label: {
                        Label("Check Off", systemImage: "checkmark.circle")
                    }
                }
                
                Button(role: .destructive) {
                    onMenu?()
                } label: {
                    Label("Remove Block", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textTertiary)
                    .frame(width: 28, height: 28)
            }
        }
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
    
    // MARK: - Circular Timer
    
    private var circularTimer: some View {
        let progress = block.duration > 0 ? min(1, block.elapsedTime / block.duration) : 0
        let isOverrun = block.elapsedTime > block.duration
        let color: Color = isOverrun ? Theme.error : block.categoryColor
        
        return ZStack {
            // Track
            Circle()
                .stroke(Theme.backgroundTertiary, lineWidth: 3)
                .frame(width: 40, height: 40)
            
            // Fill arc
            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
            
            // Inner fill glow
            Circle()
                .fill(color.opacity(0.08))
                .frame(width: 34, height: 34)
            
            // Time text
            Text(block.formattedRemaining)
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundColor(isOverrun ? Theme.error : Theme.textPrimary)
        }
    }
    
    // MARK: - Background
    
    private var blockBackground: some View {
        Group {
            if isActive && !block.isChecked {
                // Active: subtle gradient from category color
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
