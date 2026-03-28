//
//  StatsView.swift
//  CueIn
//
//  Stats mode — heatmap, charts, averages. Neutral styling.
//

import SwiftUI

struct StatsView: View {
    @ObservedObject var viewModel: MonitorViewModel
    @AppStorage(CommitmentRatingSetting.storageKey) private var isCommitmentRatingEnabled = CommitmentRatingSetting.defaultValue
    
    @State private var showBarChart: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLG) {
            if viewModel.hasLiveSessionMetrics {
                liveTodaySection
            }

            HStack(spacing: Theme.spacingMD) {
                statBox(
                    title: "Streak",
                    value: "\(viewModel.streak)",
                    unit: "days",
                    icon: "flame.fill",
                    color: Theme.warning
                )
                
                statBox(
                    title: "7d Adherence",
                    value: "\(Int(viewModel.averageAdherence * 100))%",
                    unit: "avg",
                    icon: "target",
                    color: Theme.success
                )
            }

            if isCommitmentRatingEnabled {
                statBox(
                    title: "7d Commitment",
                    value: "\(Int(viewModel.averageCommitment * 100))%",
                    unit: "avg",
                    icon: "star.fill",
                    color: Theme.warning
                )
            }
            
            // Consistency
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                HStack {
                    Text("History")
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Button(action: { showBarChart.toggle() }) {
                        Image(systemName: showBarChart ? "square.grid.3x3" : "chart.bar.fill")
                            .font(.system(size: 14))
                            .foregroundColor(Theme.selectionForeground)
                            .padding(Theme.spacingSM)
                            .background(Theme.selectionBackground)
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
                subcategoryAverages: viewModel.subcategoryAverages,
                categoryCommitmentAverages: viewModel.categoryCommitmentAverages,
                showsCommitment: isCommitmentRatingEnabled
            )
        }
    }

    private var liveTodaySection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack {
                Text("Live Today")
                    .font(Theme.heading3())
                    .foregroundColor(Theme.textPrimary)

                Spacer()

                Text("updates now")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(Theme.success)
            }

            CueCard {
                VStack(alignment: .leading, spacing: Theme.spacingMD) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.liveFormulaName)
                                .font(Theme.body1())
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.textPrimary)

                            Text(viewModel.liveCurrentBlockName)
                                .font(Theme.caption())
                                .foregroundColor(Theme.textSecondary)
                        }

                        Spacer()

                        Text(viewModel.liveCheckedLabel)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)
                    }

                    HStack(spacing: Theme.spacingMD) {
                        statBox(
                            title: "Done",
                            value: viewModel.liveCompletionLabel,
                            unit: "today",
                            icon: "checkmark.circle.fill",
                            color: Theme.success
                        )

                        statBox(
                            title: "Elapsed",
                            value: viewModel.liveElapsedLabel,
                            unit: "live",
                            icon: "timer",
                            color: Theme.info
                        )
                    }

                    HStack(spacing: Theme.spacingMD) {
                        statBox(
                            title: "Remaining",
                            value: viewModel.liveRemainingLabel,
                            unit: "left",
                            icon: "hourglass",
                            color: Theme.warning
                        )

                        if isCommitmentRatingEnabled {
                            statBox(
                                title: "Commitment",
                                value: viewModel.liveCommitmentLabel,
                                unit: viewModel.hasLiveCommitment ? "live" : "rate",
                                icon: "star.fill",
                                color: Theme.warning
                            )
                        }
                    }

                    CategoryAllocationCompactStrip(
                        title: "LIVE CATEGORY LOAD",
                        allocations: viewModel.liveCategoryAllocations,
                        trailingLabel: viewModel.liveElapsedLabel
                    )
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
        .frame(maxWidth: .infinity)
    }
}
