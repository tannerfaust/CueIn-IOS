//
//  BarChartView.swift
//  CueIn
//
//  7-day bar chart showing daily efficiency.
//

import SwiftUI

struct BarChartView: View {
    let data: [(date: Date, adherence: Double)]
    
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "E"
        return f
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("Last 7 Days")
                .font(Theme.caption())
                .foregroundColor(Theme.textTertiary)
            
            HStack(alignment: .bottom, spacing: Theme.spacingSM) {
                ForEach(data.indices, id: \.self) { index in
                    let item = data[index]
                    
                    VStack(spacing: 4) {
                        // Percentage
                        Text("\(Int(item.adherence * 100))%")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(Theme.textTertiary)
                        
                        // Bar
                        RoundedRectangle(cornerRadius: 4)
                            .fill(barColor(adherence: item.adherence))
                            .frame(height: max(4, CGFloat(item.adherence) * 80))
                            .animation(.easeInOut(duration: 0.5).delay(Double(index) * 0.05), value: item.adherence)
                        
                        // Day label
                        Text(dateFormatter.string(from: item.date))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 110)
        }
    }
    
    private func barColor(adherence: Double) -> LinearGradient {
        let color = adherence > 0.7 ? Theme.success : (adherence > 0.4 ? Theme.warning : Theme.error)
        return LinearGradient(
            colors: [color.opacity(0.6), color],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}
