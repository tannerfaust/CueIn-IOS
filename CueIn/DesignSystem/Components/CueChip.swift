//
//  CueChip.swift
//  CueIn
//
//  Category/tag chip component.
//

import SwiftUI

struct CueChip: View {
    let label: String
    var color: Color = Theme.accent
    var icon: String? = nil
    
    var body: some View {
        HStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(label)
                .font(Theme.caption())
                .fontWeight(.medium)
        }
        .padding(.horizontal, Theme.spacingSM)
        .padding(.vertical, Theme.spacingXS)
        .foregroundColor(color)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
    }
}
