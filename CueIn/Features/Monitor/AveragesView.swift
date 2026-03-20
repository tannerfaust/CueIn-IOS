//
//  AveragesView.swift
//  CueIn
//
//  Per-category average durations with expandable subcategories.
//

import SwiftUI

struct AveragesView: View {
    let categoryAverages: [(category: BlockCategory, duration: TimeInterval)]
    let subcategoryAverages: [(name: String, duration: TimeInterval)]
    
    @State private var expandedCategory: BlockCategory? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("Averages")
                .font(Theme.heading3())
                .foregroundColor(Theme.textPrimary)
            
            ForEach(categoryAverages, id: \.category) { item in
                VStack(spacing: 0) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            expandedCategory = expandedCategory == item.category ? nil : item.category
                        }
                    }) {
                        HStack {
                            Image(systemName: item.category.icon)
                                .font(.system(size: 14))
                                .foregroundColor(item.category.color)
                                .frame(width: 28)
                            
                            Text(item.category.displayName)
                                .font(Theme.body1())
                                .fontWeight(.medium)
                                .foregroundColor(Theme.textPrimary)
                            
                            Spacer()
                            
                            Text("avg \(StatsEngine.formatDuration(item.duration))/day")
                                .font(Theme.mono())
                                .foregroundColor(Theme.textSecondary)
                            
                            Image(systemName: expandedCategory == item.category ? "chevron.up" : "chevron.down")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }
                        .padding(Theme.spacingMD)
                    }
                    .buttonStyle(.plain)
                    
                    // Subcategories
                    if expandedCategory == item.category {
                        let subs = subcategoryAverages.filter { sub in
                            item.category.defaultSubcategories.contains(sub.name)
                        }
                        
                        VStack(spacing: 0) {
                            ForEach(subs, id: \.name) { sub in
                                HStack {
                                    Text("├─")
                                        .font(Theme.mono())
                                        .foregroundColor(Theme.textTertiary)
                                        .frame(width: 28)
                                    
                                    Text(sub.name)
                                        .font(Theme.body2())
                                        .foregroundColor(Theme.textSecondary)
                                    
                                    Spacer()
                                    
                                    Text(StatsEngine.formatDuration(sub.duration))
                                        .font(Theme.mono())
                                        .foregroundColor(Theme.textTertiary)
                                }
                                .padding(.horizontal, Theme.spacingMD)
                                .padding(.vertical, Theme.spacingXS)
                            }
                        }
                        .padding(.bottom, Theme.spacingSM)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .background(Theme.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
            }
        }
    }
}
