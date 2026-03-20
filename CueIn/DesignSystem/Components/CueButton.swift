//
//  CueButton.swift
//  CueIn
//
//  Reusable styled button component.
//

import SwiftUI

struct CueButton: View {
    let title: String
    var icon: String? = nil
    var style: ButtonStyle = .primary
    var isCompact: Bool = false
    let action: () -> Void
    
    enum ButtonStyle {
        case primary, secondary, destructive, ghost
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Theme.spacingSM) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: isCompact ? 12 : 14, weight: .semibold))
                }
                Text(title)
                    .font(isCompact ? Theme.caption() : Theme.body2())
                    .fontWeight(.semibold)
            }
            .padding(.horizontal, isCompact ? Theme.spacingMD : Theme.spacingLG)
            .padding(.vertical, isCompact ? Theme.spacingSM : Theme.spacingMD)
            .frame(maxWidth: isCompact ? nil : .infinity)
            .foregroundColor(foregroundColor)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: isCompact ? Theme.radiusSM : Theme.radiusMD))
            .overlay(
                RoundedRectangle(cornerRadius: isCompact ? Theme.radiusSM : Theme.radiusMD)
                    .stroke(borderColor, lineWidth: style == .secondary ? 1 : 0)
            )
        }
    }
    
    private var foregroundColor: Color {
        switch style {
        case .primary:     return .black
        case .secondary:   return Theme.textPrimary
        case .destructive: return .white
        case .ghost:       return Theme.textSecondary
        }
    }
    
    @ViewBuilder
    private var background: some View {
        switch style {
        case .primary:
            Color.white
        case .secondary:
            Color.clear
        case .destructive:
            Theme.error
        case .ghost:
            Color.clear
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .secondary: return Theme.divider
        default:         return .clear
        }
    }
}
