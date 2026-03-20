//
//  StatsView.swift
//  CueIn
//
//  Stats mode — heatmap, charts, averages. Neutral styling.
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: MonitorViewModel
    
    @State private var showBarChart: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLG) {
            // Streak & Adherence
            HStack(spacing: Theme.spacingMD) {
                statBox(
                    title: "Streak",
                    value: "\(viewModel.streak)",
                    unit: "days",
                    icon: "flame.fill",
                    color: Theme.warning
                )
                
                statBox(
                    title: "Adherence",
                    value: "\(Int(viewModel.averageAdherence * 100))%",
                    unit: "avg",
                    icon: "target",
                    color: Theme.success
                )
            }
            
            // Consistency
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                HStack {
                    Text("Consistency")
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { showBarChart.toggle() }) {
                        Image(systemName: showBarChart ? "square.grid.3x3" : "chart.bar.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.white)
                            .padding(Theme.spacingSM)
                            .background(Theme.backgroundElevated)
                            .clipShape(Circle())
                    }
                }
                
                CueCard {
                    if showBarChart {
                        BarChartView(data: viewModel.last7DaysAdherence)
                    } else {
                        HeatmapView(data: viewModel.dailyAdherence)
                    }
                }
            }
            
            // Averages
            AveragesView(
                categoryAverages: viewModel.categoryAverages,
                subcategoryAverages: viewModel.subcategoryAverages
            )
            
            // Data Lab — stub
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Text("Data Lab")
                    .font(Theme.heading3())
                    .foregroundColor(Theme.textPrimary)
                
                CueCard {
                    HStack {
                        Image(systemName: "flask.fill")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.textSecondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Coming Soon")
                                .font(Theme.body1())
                                .fontWeight(.medium)
                                .foregroundColor(Theme.textPrimary)
                            
                            Text("Explore your data like a personal data scientist")
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }
    
    private func statBox(title: String, value: String, unit: String, icon: String, color: Color) -> some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                HStack {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(color)
                    Text(title)
                        .font(Theme.caption())
                        .foregroundColor(Theme.textSecondary)
                }
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(unit)
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
    }
}
