//
//  FormulaCard.swift
//  CueIn
//
//  Formula list card component — neutral dark styling.
//

import SwiftUI

struct FormulaCard: View {
    let formula: Formula
    var onTap: (() -> Void)? = nil
    
    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: Theme.spacingMD) {
                // Emoji
                Text(formula.emoji)
                    .font(.system(size: 24))
                    .frame(width: 40, height: 40)
                    .background(Theme.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                
                // Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(formula.name)
                        .font(Theme.body1())
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)
                    
                    HStack(spacing: Theme.spacingSM) {
                        Label("\(formula.blockCount)", systemImage: "square.stack.3d.up")
                        Label(formula.formattedTargetDuration, systemImage: "clock")
                    }
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
                }
                
                Spacer()
                
                // Type
                if formula.type == .mini {
                    Text("MINI")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Theme.warning)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.warning.opacity(0.1))
                        .clipShape(Capsule())
                }
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
            .padding(Theme.spacingMD)
            .background(Theme.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
        }
        .buttonStyle(.plain)
    }
}
