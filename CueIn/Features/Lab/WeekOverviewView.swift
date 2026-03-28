//
//  WeekOverviewView.swift
//  CueIn
//
//  7-day week strip showing formula assignments.
//

import SwiftUI

struct WeekOverviewView: View {
    @ObservedObject var viewModel: LabViewModel
    var onSelectDay: ((DayOfWeek) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: Theme.spacingSM) {
                    ForEach(DayOfWeek.allCases) { day in
                        dayCard(day)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
    
    private func dayCard(_ day: DayOfWeek) -> some View {
        let isToday = day == DayOfWeek.today
        let assignment = viewModel.assignment(for: day)
        let formulas = viewModel.formulasForDay(day)

        return Group {
            if let onSelectDay {
                Button {
                    onSelectDay(day)
                } label: {
                    cardContent(isToday: isToday, day: day, assignment: assignment, formulas: formulas)
                }
                .buttonStyle(.plain)
            } else {
                cardContent(isToday: isToday, day: day, assignment: assignment, formulas: formulas)
            }
        }
    }

    @ViewBuilder
    private func cardContent(
        isToday: Bool,
        day: DayOfWeek,
        assignment: DayAssignment,
        formulas: [Formula]
    ) -> some View {
        Group {
            Group {
                if isToday {
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        Text("TODAY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.selectionForeground)
                            .padding(.horizontal, Theme.spacingSM)
                            .padding(.vertical, 6)
                            .background(Theme.selectionBackground)
                            .clipShape(Capsule())

                        VStack(alignment: .leading, spacing: 4) {
                            Text(assignment.resolvedTitle)
                                .font(Theme.body1())
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(1)

                            Text(formulas.isEmpty ? "No formula assigned yet." : formulas.map(\.name).joined(separator: " • "))
                                .font(.system(size: 12))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)

                        HStack(spacing: 8) {
                            Text(day.displayName)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(Theme.textSecondary)

                            Spacer()

                            Text(formulas.isEmpty ? "Edit" : "\(formulas.count) formula\(formulas.count == 1 ? "" : "s")")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Theme.textTertiary)
                        }
                    }
                    .frame(width: 184, height: 126, alignment: .leading)
                    .padding(Theme.spacingMD)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMD)
                            .stroke(Theme.accent.opacity(0.28), lineWidth: 1)
                    )
                } else {
                    VStack(alignment: .leading, spacing: Theme.spacingXS) {
                        Text(day.shortName.uppercased())
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(Theme.textTertiary)

                        Spacer(minLength: 0)

                        Text(formulas.first?.emoji ?? "·")
                            .font(.system(size: 18))

                        Text(assignment.resolvedTitle)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(2)
                    }
                    .frame(width: 88, height: 88, alignment: .leading)
                    .padding(Theme.spacingSM)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.radiusMD)
                            .stroke(Theme.surfaceStroke, lineWidth: 1)
                    )
                }
            }
        }
    }
}
