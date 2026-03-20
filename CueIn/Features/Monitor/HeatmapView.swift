//
//  HeatmapView.swift
//  CueIn
//
//  GitHub-style consistency heatmap (30-day grid).
//

import SwiftUI

struct HeatmapView: View {
    let data: [(date: Date, adherence: Double)]
    
    private let columns = Array(repeating: GridItem(.fixed(14), spacing: 3), count: 7)
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("Last 30 Days")
                .font(Theme.caption())
                .foregroundColor(Theme.textTertiary)
            
            LazyVGrid(columns: columns, spacing: 3) {
                // Pad to fill grid nicely
                ForEach(paddedData.indices, id: \.self) { index in
                    let item = paddedData[index]
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cellColor(adherence: item.adherence))
                        .frame(height: 14)
                }
            }
            
            // Legend
            HStack(spacing: 4) {
                Text("Less")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textTertiary)
                
                ForEach([0.0, 0.25, 0.5, 0.75, 1.0], id: \.self) { level in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(cellColor(adherence: level))
                        .frame(width: 10, height: 10)
                }
                
                Text("More")
                    .font(.system(size: 9))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }
    
    private var paddedData: [(date: Date, adherence: Double)] {
        // Ensure we have 28 cells (4 weeks)
        var result = data
        while result.count < 28 {
            result.append((date: Date(), adherence: 0))
        }
        return Array(result.prefix(28))
    }
    
    private func cellColor(adherence: Double) -> Color {
        if adherence <= 0 {
            return Theme.backgroundTertiary
        }
        return Theme.accent.opacity(0.2 + adherence * 0.8)
    }
}
