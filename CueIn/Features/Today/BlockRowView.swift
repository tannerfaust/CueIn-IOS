//
//  BlockRowView.swift
//  CueIn
//
//  Detailed block row view with expanded info (used in formula editor).
//

import SwiftUI

struct BlockRowView: View {
    let block: Block
    var showDuration: Bool = true
    var onDelete: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: Theme.spacingMD) {
            // Category color indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(block.categoryColor)
                .frame(width: 4, height: 40)
            
            // Info
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
                }
            }
            
            Spacer()
            
            // Duration
            if showDuration {
                Text(block.formattedDuration)
                    .font(Theme.mono())
                    .foregroundColor(Theme.textSecondary)
            }
            
            // Flow logic indicator
            Image(systemName: block.flowLogic == .blocking ? "lock.fill" : "wind")
                .font(.system(size: 12))
                .foregroundColor(block.flowLogic == .blocking ? Theme.warning : Theme.textTertiary)
            
            // Delete
            if let onDelete = onDelete {
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.error.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.spacingMD)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }
}
