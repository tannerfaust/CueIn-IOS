//
//  QSView.swift
//  CueIn
//
//  QS mode — data entry, history, journal, edit/delete inputs.
//

import SwiftUI

struct QSView: View {
    @ObservedObject var viewModel: MonitorViewModel
    
    @State private var qsMode: QSSubMode = .today
    @State private var newEntryName: String = ""
    @State private var newEntryType: QSInputType = .number
    @State private var newEntryIcon: String = "star"
    
    enum QSSubMode: String, CaseIterable {
        case today = "Today"
        case history = "History"
        case journal = "Journal"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.spacingLG) {
            // Sub-mode toggle
            HStack(spacing: 0) {
                ForEach(QSSubMode.allCases, id: \.self) { mode in
                    Button {
                        withAnimation { qsMode = mode }
                    } label: {
                        Text(mode.rawValue)
                            .font(Theme.caption())
                            .fontWeight(.semibold)
                            .foregroundColor(qsMode == mode ? .white : Theme.textTertiary)
                            .padding(.horizontal, Theme.spacingMD)
                            .padding(.vertical, Theme.spacingSM)
                            .background(qsMode == mode ? Theme.backgroundElevated : Color.clear)
                            .clipShape(Capsule())
                    }
                }
            }
            .background(Theme.backgroundTertiary)
            .clipShape(Capsule())
            
            switch qsMode {
            case .today:
                todaySection
            case .history:
                historySection
            case .journal:
                journalSection
            }
        }
    }
    
    // MARK: - Today
    
    private var todaySection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack {
                Text("Today's Inputs")
                    .font(Theme.heading3())
                    .foregroundColor(Theme.textPrimary)
                
                Spacer()
                
                Menu {
                    Button {
                        viewModel.showAddQS = true
                    } label: {
                        Label("Add Input", systemImage: "plus")
                    }
                    
                    Button {
                        viewModel.showEditQS = true
                    } label: {
                        Label("Edit Inputs", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 18))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            
            ForEach(viewModel.dataStore.qsEntries) { entry in
                qsEntryRow(entry)
            }
            
            if viewModel.dataStore.qsEntries.isEmpty {
                CueCard {
                    HStack {
                        Spacer()
                        VStack(spacing: Theme.spacingSM) {
                            Image(systemName: "chart.bar.doc.horizontal")
                                .font(.system(size: 24))
                                .foregroundColor(Theme.textTertiary)
                            Text("No QS inputs. Tap ⋯ to add one.")
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, Theme.spacingLG)
                }
            }
        }
        .sheet(isPresented: $viewModel.showAddQS) {
            addQSSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showEditQS) {
            editQSSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func qsEntryRow(_ entry: QSEntry) -> some View {
        let currentValue = viewModel.recordValue(for: entry)
        
        return CueCard {
            HStack(spacing: Theme.spacingMD) {
                Image(systemName: entry.icon)
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Theme.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.name)
                        .font(Theme.body2())
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)
                    
                    Text(entry.automation.displayName)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
                
                Spacer()
                
                // Input control
                qsInput(for: entry, currentValue: currentValue)
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
            HStack(spacing: 4) {
                TextField("0", text: Binding(
                    get: { currentValue ?? "" },
                    set: { viewModel.saveQSValue($0, for: entry) }
                ))
                .font(Theme.mono())
                .foregroundColor(Theme.textPrimary)
                .keyboardType(.decimalPad)
                .frame(width: 60)
                .multilineTextAlignment(.trailing)
                .padding(Theme.spacingXS)
                .background(Theme.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
            }
            
        case .text:
            TextField("...", text: Binding(
                get: { currentValue ?? "" },
                set: { viewModel.saveQSValue($0, for: entry) }
            ))
            .font(Theme.body2())
            .foregroundColor(Theme.textPrimary)
            .frame(width: 120)
            .padding(Theme.spacingXS)
            .background(Theme.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
            
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
                    .foregroundColor(currentValue != nil ? Theme.textPrimary : Theme.textTertiary)
                    .padding(.horizontal, Theme.spacingSM)
                    .padding(.vertical, Theme.spacingXS)
                    .background(Theme.backgroundTertiary)
                    .clipShape(Capsule())
            }
            
        case .time:
            Text(currentValue ?? "--:--")
                .font(Theme.mono())
                .foregroundColor(Theme.textSecondary)
        }
    }
    
    // MARK: - History
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("QS History")
                .font(Theme.heading3())
                .foregroundColor(Theme.textPrimary)
            
            if viewModel.recordsByDay.isEmpty {
                CueCard {
                    HStack {
                        Spacer()
                        Text("No records yet. Start logging today.")
                            .font(Theme.caption())
                            .foregroundColor(Theme.textTertiary)
                        Spacer()
                    }
                    .padding(.vertical, Theme.spacingLG)
                }
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
                    HStack {
                        Text(record.entryName)
                            .font(Theme.body2())
                            .foregroundColor(Theme.textPrimary)
                        
                        Spacer()
                        
                        Text(record.value)
                            .font(Theme.mono())
                            .foregroundColor(Theme.textSecondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Journal
    
    private var journalSection: some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("Journal")
                .font(Theme.heading3())
                .foregroundColor(Theme.textPrimary)
            
            Text("Daily notes from your QS entries")
                .font(Theme.caption())
                .foregroundColor(Theme.textTertiary)
            
            let journalRecords = viewModel.dataStore.qsRecords
                .filter { record in
                    viewModel.dataStore.qsEntries
                        .first(where: { $0.id == record.entryId })?.inputType == .text
                }
                .sorted { $0.date > $1.date }
            
            if journalRecords.isEmpty {
                CueCard {
                    HStack {
                        Spacer()
                        VStack(spacing: Theme.spacingSM) {
                            Image(systemName: "note.text")
                                .font(.system(size: 24))
                                .foregroundColor(Theme.textTertiary)
                            Text("No journal entries yet. Add a text-type QS input to start journaling.")
                                .font(Theme.caption())
                                .foregroundColor(Theme.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    }
                    .padding(.vertical, Theme.spacingLG)
                }
            } else {
                ForEach(journalRecords.prefix(20)) { record in
                    journalEntry(record)
                }
            }
        }
    }
    
    private func journalEntry(_ record: QSRecord) -> some View {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        
        return CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                HStack {
                    Image(systemName: "note.text")
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
                
                Text(record.value)
                    .font(Theme.body2())
                    .foregroundColor(Theme.textPrimary)
                    .lineSpacing(4)
            }
        }
    }
    
    // MARK: - Add QS Sheet
    
    private var addQSSheet: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                Text("Add Input")
                    .font(Theme.heading2())
                    .foregroundColor(Theme.textPrimary)
                    .padding(.top, Theme.spacingLG)
                
                TextField("Input name", text: $newEntryName)
                    .font(Theme.body1())
                    .foregroundColor(Theme.textPrimary)
                    .padding(Theme.spacingMD)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                
                Text("TYPE")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)
                
                HStack(spacing: Theme.spacingSM) {
                    ForEach([QSInputType.boolean, .number, .text], id: \.self) { type in
                        Button {
                            newEntryType = type
                        } label: {
                            Text(type.displayName)
                                .font(Theme.caption())
                                .fontWeight(.medium)
                                .foregroundColor(newEntryType == type ? .white : Theme.textSecondary)
                                .padding(.horizontal, Theme.spacingMD)
                                .padding(.vertical, Theme.spacingSM)
                                .background(newEntryType == type ? Theme.backgroundElevated : Theme.backgroundCard)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                CueButton(title: "Add", icon: "plus") {
                    viewModel.addQSEntry(name: newEntryName, inputType: newEntryType, icon: newEntryIcon)
                    newEntryName = ""
                    viewModel.showAddQS = false
                }
                .disabled(newEntryName.isEmpty)
                .opacity(newEntryName.isEmpty ? 0.5 : 1)
                
                Spacer()
            }
            .padding(.horizontal, Theme.spacingMD)
        }
    }
    
    // MARK: - Edit QS Sheet
    
    private var editQSSheet: some View {
        ZStack {
            Theme.backgroundSecondary.ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                HStack {
                    Text("Edit Inputs")
                        .font(Theme.heading2())
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    Button("Done") { viewModel.showEditQS = false }
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                }
                .padding(.top, Theme.spacingLG)
                
                ForEach(viewModel.dataStore.qsEntries) { entry in
                    HStack(spacing: Theme.spacingMD) {
                        Image(systemName: entry.icon)
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textSecondary)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.name)
                                .font(Theme.body2())
                                .foregroundColor(Theme.textPrimary)
                            Text(entry.inputType.displayName)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textTertiary)
                        }
                        
                        Spacer()
                        
                        Button(role: .destructive) {
                            viewModel.deleteQSEntry(entry)
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.error)
                        }
                    }
                    .padding(Theme.spacingMD)
                    .background(Theme.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
                }
                
                Spacer()
            }
            .padding(.horizontal, Theme.spacingMD)
        }
    }
}
