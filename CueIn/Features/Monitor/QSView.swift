//
//  QSView.swift
//  CueIn
//
//  QS mode — daily inputs, history, journal, presets, and per-input editing.
//

import SwiftUI

private struct QSJournalTarget: Identifiable {
    let id = UUID()
    let entry: QSEntry
    let date: Date
}

struct QSView: View {
    @ObservedObject var viewModel: MonitorViewModel

    @State private var qsMode: QSSubMode = .today
    @State private var showEntryEditor = false
    @State private var editingEntry: QSEntry?
    @State private var showPresetLibrary = false
    @State private var journalTarget: QSJournalTarget?

    enum QSSubMode: String, CaseIterable {
        case today = "Today"
        case history = "History"
        case journal = "Journal"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLG) {
            modeToggle

            switch qsMode {
            case .today:
                todaySection
            case .history:
                historySection
            case .journal:
                journalSection
            }
        }
        .sheet(isPresented: $showEntryEditor) {
            QSEntryEditorView(
                entry: editingEntry,
                onSave: { entry in
                    if viewModel.dataStore.qsEntries.contains(where: { $0.id == entry.id }) {
                        viewModel.updateQSEntry(entry)
                    } else {
                        viewModel.addQSEntry(entry)
                    }
                },
                onDelete: editingEntry.map { entry in
                    { viewModel.deleteQSEntry(entry) }
                }
            )
        }
        .sheet(isPresented: $showPresetLibrary) {
            QSPresetLibraryView { preset in
                viewModel.addQSEntry(preset.entry)
                showPresetLibrary = false
            }
        }
        .sheet(item: $journalTarget) { target in
            JournalEditorView(viewModel: viewModel, entry: target.entry, date: target.date)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(QSSubMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        qsMode = mode
                    }
                } label: {
                    Text(mode.rawValue)
                        .font(Theme.caption())
                        .fontWeight(.semibold)
                        .foregroundColor(qsMode == mode ? Theme.selectionForeground : Theme.textTertiary)
                        .padding(.horizontal, Theme.spacingMD)
                        .padding(.vertical, Theme.spacingSM)
                        .background(qsMode == mode ? Theme.selectionBackground : Color.clear)
                        .clipShape(Capsule())
                }
            }
        }
        .background(Theme.backgroundTertiary)
        .clipShape(Capsule())
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Today's Inputs")
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)

                    Text("Presets, reminders, and journal prompts live here.")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                }

                Spacer()

                Menu {
                    Button {
                        editingEntry = nil
                        showEntryEditor = true
                    } label: {
                        Label("New Input", systemImage: "plus")
                    }

                    Button {
                        showPresetLibrary = true
                    } label: {
                        Label("Preset Library", systemImage: "square.grid.2x2")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.textSecondary)
                }
            }

            if viewModel.dataStore.qsEntries.isEmpty {
                emptyState(
                    icon: "chart.bar.doc.horizontal",
                    title: "No QS inputs yet",
                    body: "Add a custom input or pull one from the preset library."
                )
            } else {
                ForEach(viewModel.dataStore.qsEntries) { entry in
                    qsEntryRow(entry)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button {
                                editingEntry = entry
                                showEntryEditor = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(Theme.info)

                            Button(role: .destructive) {
                                viewModel.deleteQSEntry(entry)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
        }
    }

    private func qsEntryRow(_ entry: QSEntry) -> some View {
        let currentValue = viewModel.recordValue(for: entry)
        let journalPreview = (entry.inputType == .journal || entry.inputType == .text)
            ? viewModel.journalContent(for: entry).previewText
            : nil

        return CueCard {
            HStack(alignment: .center, spacing: Theme.spacingMD) {
                Image(systemName: entry.icon)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 34, height: 34)
                    .background(Theme.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))

                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.name)
                        .font(Theme.body2())
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)

                    Text(journalPreview ?? "\(entry.automation.displayName) • \(entry.trigger.summary)")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                        .lineLimit(2)
                }

                Spacer(minLength: Theme.spacingSM)

                qsInput(for: entry, currentValue: currentValue)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if entry.inputType == .journal || entry.inputType == .text {
                journalTarget = QSJournalTarget(entry: entry, date: Date())
            }
        }
    }

    @ViewBuilder
    private func qsInput(for entry: QSEntry, currentValue: String?) -> some View {
        switch entry.inputType {
        case .boolean:
            Toggle("", isOn: Binding(
                get: { currentValue == "true" },
                set: { viewModel.saveQSValue($0 ? "true" : "false", for: entry) }
            ))
            .toggleStyle(SwitchToggleStyle(tint: Theme.success))
            .labelsHidden()

        case .number:
            TextField("0", text: Binding(
                get: { currentValue ?? "" },
                set: { viewModel.saveQSValue($0, for: entry) }
            ))
            .font(Theme.mono())
            .foregroundColor(Theme.textPrimary)
            .keyboardType(.decimalPad)
            .frame(width: 72)
            .multilineTextAlignment(.trailing)
            .padding(Theme.spacingXS)
            .background(Theme.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))

        case .text, .journal:
            Button {
                journalTarget = QSJournalTarget(entry: entry, date: Date())
            } label: {
                Text(currentValue == nil ? "Open" : "Edit")
                    .font(Theme.caption())
                    .foregroundColor(Theme.selectionForeground)
                    .padding(.horizontal, Theme.spacingSM)
                    .padding(.vertical, Theme.spacingXS)
                    .background(Theme.selectionBackground)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

        case .options:
            Menu {
                ForEach(entry.options, id: \.self) { option in
                    Button {
                        viewModel.saveQSValue(option, for: entry)
                    } label: {
                        HStack {
                            Text(option)
                            if currentValue == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Text(currentValue ?? "Select")
                    .font(Theme.caption())
                    .foregroundColor(currentValue == nil ? Theme.textTertiary : Theme.textPrimary)
                    .padding(.horizontal, Theme.spacingSM)
                    .padding(.vertical, Theme.spacingXS)
                    .background(Theme.backgroundTertiary)
                    .clipShape(Capsule())
            }

        case .time:
            TextField("--:--", text: Binding(
                get: { currentValue ?? "" },
                set: { viewModel.saveQSValue($0, for: entry) }
            ))
            .font(Theme.mono())
            .foregroundColor(Theme.textPrimary)
            .frame(width: 78)
            .multilineTextAlignment(.trailing)
            .padding(Theme.spacingXS)
            .background(Theme.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("QS History")
                .font(Theme.heading3())
                .foregroundColor(Theme.textPrimary)

            if viewModel.recordsByDay.isEmpty {
                emptyState(
                    icon: "clock.arrow.circlepath",
                    title: "No QS history yet",
                    body: "Start logging today and the last records will appear here."
                )
            } else {
                ForEach(viewModel.recordsByDay.prefix(14), id: \.0) { date, records in
                    historyDayCard(date: date, records: records)
                }
            }
        }
    }

    private func historyDayCard(date: Date, records: [QSRecord]) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"

        return CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Text(formatter.string(from: date))
                    .font(Theme.caption())
                    .fontWeight(.semibold)
                    .foregroundColor(Theme.textSecondary)

                ForEach(records) { record in
                    let entry = viewModel.dataStore.qsEntries.first(where: { $0.id == record.entryId })

                    HStack(alignment: .top, spacing: Theme.spacingSM) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.entryName)
                                .font(Theme.body2())
                                .foregroundColor(Theme.textPrimary)

                            Text(entry?.trigger.summary ?? "Manual")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }

                        Spacer(minLength: Theme.spacingSM)

                        if let entry, entry.inputType == .journal || entry.inputType == .text {
                            Button("Open") {
                                journalTarget = QSJournalTarget(entry: entry, date: date)
                            }
                            .font(Theme.caption())
                            .foregroundColor(Theme.accent)
                        } else {
                            Text(viewModel.formattedQSRecordValue(record, for: entry))
                                .font(Theme.mono())
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
    }

    private var journalSection: some View {
        let journalEntries = viewModel.dataStore.qsEntries.filter { $0.inputType == .journal || $0.inputType == .text }
        let journalRecords = viewModel.dataStore.qsRecords
            .filter { record in
                journalEntries.contains(where: { $0.id == record.entryId })
            }
            .sorted { $0.date > $1.date }

        return VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Journal")
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)

                    Text("Long-form entries, photos, and end-of-day reflection live here.")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                }

                Spacer()

                Button {
                    if let journalEntry = journalEntries.first {
                        journalTarget = QSJournalTarget(entry: journalEntry, date: Date())
                    } else {
                        showPresetLibrary = true
                    }
                } label: {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }

            if journalEntries.isEmpty {
                emptyState(
                    icon: "book.closed",
                    title: "No journal input yet",
                    body: "Use the preset library and add a Journal input. It opens as a full writing page with photos."
                )
            } else if journalRecords.isEmpty {
                emptyState(
                    icon: "note.text",
                    title: "No journal entries yet",
                    body: "Open your journal input from Today and write the first entry."
                )
            } else {
                ForEach(journalRecords.prefix(20)) { record in
                    journalEntryCard(record)
                }
            }
        }
    }

    private func journalEntryCard(_ record: QSRecord) -> some View {
        let entry = viewModel.dataStore.qsEntries.first(where: { $0.id == record.entryId })
        let content = entry.map { viewModel.journalContent(for: $0, on: record.date) } ?? QSJournalContent(text: record.value)

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"

        return Button {
            if let entry {
                journalTarget = QSJournalTarget(entry: entry, date: record.date)
            }
        } label: {
            CueCard {
                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    HStack {
                        Image(systemName: "book.closed")
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textTertiary)

                        Text(record.entryName)
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)

                        Spacer()

                        Text(formatter.string(from: record.date))
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }

                    Text(content.previewText)
                        .font(Theme.body2())
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(4)

                    if !content.photoFileNames.isEmpty {
                        Text("\(content.photoFileNames.count) photo" + (content.photoFileNames.count == 1 ? "" : "s"))
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(Theme.warning)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func emptyState(icon: String, title: String, body: String) -> some View {
        CueCard {
            HStack {
                Spacer()
                VStack(spacing: Theme.spacingSM) {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(Theme.textTertiary)

                    Text(title)
                        .font(Theme.body2())
                        .fontWeight(.semibold)
                        .foregroundColor(Theme.textPrimary)

                    Text(body)
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                        .multilineTextAlignment(.center)
                }
                Spacer()
            }
            .padding(.vertical, Theme.spacingLG)
        }
    }
}
