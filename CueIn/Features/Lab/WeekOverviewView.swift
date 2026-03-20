//
//  WeekOverviewView.swift
//  CueIn
//
//  7-day week strip showing formula assignments.
//

import SwiftUI

struct WeekOverviewView: View {
    @ObservedObject var viewModel: LabViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("Week Overview")
                .font(Theme.heading3())
                .foregroundColor(Theme.textPrimary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.spacingSM) {
                    ForEach(DayOfWeek.allCases) { day in
                        dayColumn(day)
                    }
                }
            }
        }
    }
    
    private func dayColumn(_ day: DayOfWeek) -> some View {
        let isToday = day == DayOfWeek.today
        let formulas = viewModel.formulasForDay(day)
        
        return VStack(spacing: Theme.spacingXS) {
            // Day label
            Text(day.shortName)
                .font(Theme.caption())
                .fontWeight(.semibold)
                .foregroundColor(isToday ? Theme.accent : Theme.textSecondary)
            
            // Formula cards
            VStack(spacing: 4) {
                if formulas.isEmpty {
                    RoundedRectangle(cornerRadius: Theme.radiusSM)
                        .fill(Theme.backgroundTertiary)
                        .frame(width: 80, height: 60)
                        .overlay(
                            Image(systemName: "plus")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.textTertiary)
                        )
                } else {
                    ForEach(formulas) { formula in
                        Button(action: { viewModel.editFormula(formula) }) {
                            VStack(spacing: 2) {
                                Text(formula.emoji)
                                    .font(.system(size: 16))
                                Text(formula.name)
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(width: 80, height: 60)
                            .background(Theme.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.radiusSM)
                                    .stroke(
                                        isToday ? Theme.accent.opacity(0.4) : Color.white.opacity(0.05),
                                        lineWidth: 1
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
