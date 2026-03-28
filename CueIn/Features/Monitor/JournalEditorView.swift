//
//  JournalEditorView.swift
//  CueIn
//
//  Full-screen QS journal editor with photo attachments.
//

import SwiftUI
import PhotosUI
import UIKit

private struct JournalPhotoDraft: Identifiable {
    let id = UUID()
    var fileName: String?
    var image: UIImage
}

struct JournalEditorView: View {
    @ObservedObject var viewModel: MonitorViewModel
    let entry: QSEntry
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var photoDrafts: [JournalPhotoDraft]
    @State private var selectedItems: [PhotosPickerItem] = []

    init(viewModel: MonitorViewModel, entry: QSEntry, date: Date) {
        self.viewModel = viewModel
        self.entry = entry
        self.date = date

        let content = viewModel.journalContent(for: entry, on: date)
        _text = State(initialValue: content.text)
        _photoDrafts = State(initialValue: content.photoFileNames.compactMap { fileName in
            let url = viewModel.dataStore.journalPhotoURL(for: fileName)
            guard let image = UIImage(contentsOfFile: url.path) else { return nil }
            return JournalPhotoDraft(fileName: fileName, image: image)
        })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundSecondary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                                Text(entry.name)
                                    .font(Theme.heading3())
                                    .foregroundColor(Theme.textPrimary)

                                Text(formattedDate)
                                    .font(Theme.caption())
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }

                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                                Text("Entry")
                                    .font(Theme.heading3())
                                    .foregroundColor(Theme.textPrimary)

                                TextEditor(text: $text)
                                    .scrollContentBackground(.hidden)
                                    .foregroundColor(Theme.textPrimary)
                                    .frame(minHeight: 260)
                                    .padding(Theme.spacingSM)
                                    .background(Theme.backgroundTertiary)
                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                            }
                        }

                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                                HStack {
                                    Text("Photos")
                                        .font(Theme.heading3())
                                        .foregroundColor(Theme.textPrimary)

                                    Spacer()

                                    PhotosPicker(selection: $selectedItems, maxSelectionCount: 6, matching: .images) {
                                        HStack(spacing: Theme.spacingXS) {
                                            Image(systemName: "photo.on.rectangle")
                                            Text("Add Photo")
                                        }
                                        .font(Theme.body2())
                                        .foregroundColor(Theme.selectionForeground)
                                        .padding(.horizontal, Theme.spacingMD)
                                        .padding(.vertical, Theme.spacingSM)
                                        .background(Theme.selectionBackground)
                                        .clipShape(Capsule())
                                    }
                                }

                                if photoDrafts.isEmpty {
                                    Text("Add photos if you want context, receipts, whiteboards, meals, or anything else tied to the day.")
                                        .font(Theme.caption())
                                        .foregroundColor(Theme.textTertiary)
                                } else {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: Theme.spacingSM) {
                                            ForEach(photoDrafts) { draft in
                                                ZStack(alignment: .topTrailing) {
                                                    Image(uiImage: draft.image)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 120, height: 120)
                                                        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))

                                                    Button {
                                                        photoDrafts.removeAll { $0.id == draft.id }
                                                    } label: {
                                                        Image(systemName: "xmark.circle.fill")
                                                            .font(.system(size: 18))
                                                            .foregroundColor(.white)
                                                            .background(Color.black.opacity(0.35))
                                                            .clipShape(Circle())
                                                    }
                                                    .padding(6)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(Theme.spacingMD)
                }
            }
            .navigationTitle("Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveJournal()
                        dismiss()
                    }
                }
            }
            .task(id: selectedItems) {
                await loadSelectedPhotos()
            }
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    private func saveJournal() {
        var fileNames: [String] = []

        for draft in photoDrafts {
            if let fileName = draft.fileName {
                fileNames.append(fileName)
            } else if let fileName = viewModel.dataStore.saveJournalPhoto(draft.image) {
                fileNames.append(fileName)
            }
        }

        let content = QSJournalContent(text: text, photoFileNames: fileNames)
        viewModel.saveJournalContent(content, for: entry, on: date)
    }

    @MainActor
    private func loadSelectedPhotos() async {
        guard !selectedItems.isEmpty else { return }

        let items = selectedItems
        selectedItems = []

        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else { continue }
            photoDrafts.append(JournalPhotoDraft(fileName: nil, image: image))
        }
    }
}
