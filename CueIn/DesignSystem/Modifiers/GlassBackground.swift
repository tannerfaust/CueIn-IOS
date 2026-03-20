//
//  GlassBackground.swift
//  CueIn
//
//  Glassmorphism view modifier.
//

import SwiftUI

// MARK: - Glass Background Modifier

struct GlassBackground: ViewModifier {
    var cornerRadius: CGFloat = Theme.radiusMD
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassBackground(cornerRadius: CGFloat = Theme.radiusMD) -> some View {
        modifier(GlassBackground(cornerRadius: cornerRadius))
    }
}
