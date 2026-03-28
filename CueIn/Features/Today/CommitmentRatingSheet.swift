//
//  CommitmentRatingSheet.swift
//  CueIn
//
//  Rate how fully a completed block was executed.
//

import SwiftUI

struct CommitmentRatingSheet: View {
    let blockName: String
    @Binding var rating: Int
    var onClear: (() -> Void)? = nil
    var onSave: () -> Void

    var body: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: Theme.spacingLG) {
                Text("Commitment")
                    .font(Theme.heading3())
                    .foregroundColor(Theme.textPrimary)

                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    Text(blockName)
                        .font(Theme.body1())
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)

                    Text(summaryText)
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                }

                CommitmentStarPicker(rating: $rating)

                HStack(spacing: Theme.spacingSM) {
                    if let onClear {
                        Button(action: onClear) {
                            Text("Clear")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Theme.backgroundCard)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                        }
                        .buttonStyle(.plain)
                    }

                    Button(action: onSave) {
                        Text("Save Rating")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.onAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Theme.accent)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .padding(Theme.spacingMD)
        }
    }

    private var summaryText: String {
        let percentage = rating * 20
        return "\(rating)/5 stars • \(percentage)% commitment"
    }
}

private struct CommitmentStarPicker: View {
    @Binding var rating: Int

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: Theme.spacingSM) {
                ForEach(1...5, id: \.self) { index in
                    Button {
                        rating = index
                    } label: {
                        Image(systemName: index <= rating ? "star.fill" : "star")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(index <= rating ? Theme.warning : Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Theme.spacingSM)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let widthPerStar = geometry.size.width / 5
                        guard widthPerStar > 0 else { return }
                        let rawIndex = Int(value.location.x / widthPerStar) + 1
                        rating = min(5, max(1, rawIndex))
                    }
            )
        }
        .frame(height: 72)
    }
}
