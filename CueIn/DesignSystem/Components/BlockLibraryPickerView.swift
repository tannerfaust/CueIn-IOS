//
//  BlockLibraryPickerView.swift
//  CueIn
//
//  Lightweight picker for reusable saved blocks.
//

import SwiftUI

struct BlockLibraryPickerView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss

    let onSelect: (BlockLibraryItem) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundSecondary.ignoresSafeArea()

                if dataStore.blockLibrary.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(dataStore.blockLibrary.sorted { $0.createdAt > $1.createdAt }) { item in
                            Button {
                                onSelect(item)
                                dismiss()
                            } label: {
                                row(for: item)
                            }
                            .buttonStyle(.plain)
                            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    dataStore.deleteBlockLibraryItem(item)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Theme.backgroundSecondary)
                }
            }
            .navigationTitle("Saved Blocks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.spacingMD) {
            Image(systemName: "square.stack.3d.up.slash")
                .font(.system(size: 28))
                .foregroundColor(Theme.textTertiary)

            Text("No saved blocks yet.")
                .font(Theme.body1())
                .fontWeight(.semibold)
                .foregroundColor(Theme.textPrimary)

            Text("Turn on “Save to library” when creating a block, and it will show up here for reuse.")
                .font(Theme.body2())
                .foregroundColor(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Theme.spacingLG)
        }
    }

    private func row(for item: BlockLibraryItem) -> some View {
        HStack(alignment: .top, spacing: Theme.spacingSM) {
            RoundedRectangle(cornerRadius: 3)
                .fill(item.category.color)
                .frame(width: 4, height: 42)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: Theme.spacingXS) {
                    Text(item.name)
                        .font(Theme.body2())
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)

                    if item.miniFormulaId != nil {
                        Text("MINI")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(Theme.selectionForeground)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Theme.selectionBackground)
                            .clipShape(Capsule())
                    }
                }

                Text(detailLine(for: item))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .padding(.top, 2)
        }
        .padding(.horizontal, Theme.spacingSM)
        .padding(.vertical, Theme.spacingXS)
    }

    private func detailLine(for item: BlockLibraryItem) -> String {
        var parts = [
            item.category.displayName,
            item.duration.formattedLibraryDuration,
            item.priority.displayName,
            item.flowLogic.displayName
        ]

        let trimmedSubcategory = item.subcategory.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSubcategory.isEmpty {
            parts.insert(trimmedSubcategory, at: 1)
        }

        return parts.joined(separator: " • ")
    }
}

private extension TimeInterval {
    var formattedLibraryDuration: String {
        let minutes = Int(self) / 60
        if minutes >= 60 {
            let hours = minutes / 60
            let remainder = minutes % 60
            return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
        }
        return "\(minutes)m"
    }
}
