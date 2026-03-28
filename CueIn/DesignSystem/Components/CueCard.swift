//
//  CueCard.swift
//  CueIn
//
//  Reusable card container component.
//

import SwiftUI

struct CueCard<Content: View>: View {
    var padding: CGFloat = Theme.spacingMD
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            content()
        }
        .padding(padding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusMD)
                .stroke(Theme.surfaceStroke, lineWidth: 1)
        )
    }
}
