//
//  CueProgressBar.swift
//  CueIn
//
//  Animated progress bar — stunning "day is loading" effect.
//  Category-colored gradient with glow and pulse animation.
//

import SwiftUI

struct CueProgressBar: View {
    let progress: Double  // 0.0 – 1.0
    var height: CGFloat = 6
    var showLabel: Bool = true
    var barColor: Color = .white
    var useGradient: Bool = false
    
    @State private var shimmerOffset: CGFloat = -0.3
    
    var body: some View {
        VStack(alignment: .trailing, spacing: Theme.spacingXS) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Theme.backgroundTertiary)
                        .frame(height: height)
                    
                    // Fill
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(fillStyle)
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, progress))), height: height)
                        .animation(.easeInOut(duration: 0.5), value: progress)
                        .overlay(
                            // Shimmer overlay — "loading" effect
                            useGradient ? shimmerOverlay(width: geo.size.width * CGFloat(min(1, max(0, progress)))) : nil
                        )
                        .clipShape(RoundedRectangle(cornerRadius: height / 2))
                    
                    // Glow dot at the tip
                    if useGradient && progress > 0.01 && progress < 1.0 {
                        Circle()
                            .fill(Color.white)
                            .frame(width: height + 2, height: height + 2)
                            .shadow(color: barColor.opacity(0.6), radius: 6, x: 0, y: 0)
                            .offset(x: (geo.size.width * CGFloat(min(1, max(0, progress)))) - (height / 2 + 1))
                            .animation(.easeInOut(duration: 0.5), value: progress)
                    }
                }
            }
            .frame(height: height + (useGradient ? 2 : 0))
            
            if showLabel {
                Text("\(Int(progress * 100))%")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .onAppear {
            if useGradient {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    shimmerOffset = 1.3
                }
            }
        }
    }
    
    private var fillStyle: some ShapeStyle {
        if useGradient {
            return AnyShapeStyle(
                LinearGradient(
                    colors: [
                        barColor.opacity(0.7),
                        barColor,
                        Color.white.opacity(0.9),
                        barColor
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        } else {
            return AnyShapeStyle(barColor)
        }
    }
    
    private func shimmerOverlay(width: CGFloat) -> some View {
        LinearGradient(
            colors: [
                Color.clear,
                Color.white.opacity(0.15),
                Color.clear
            ],
            startPoint: UnitPoint(x: shimmerOffset, y: 0.5),
            endPoint: UnitPoint(x: shimmerOffset + 0.3, y: 0.5)
        )
        .frame(width: width)
    }
}
