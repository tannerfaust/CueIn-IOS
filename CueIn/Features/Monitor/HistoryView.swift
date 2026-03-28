//
//  HistoryView.swift
//  CueIn
//
//  Calendar-based history browser with day drilldown and QS editing.
//

import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: MonitorViewModel

    @State private var displayedMonth = Calendar.current.startOfMonth(for: Date())
    @State private var selectedDate: Date? = nil

    var body: some View {
        GeometryReader { proxy in
            let compactWidth = proxy.size.width < 370

            ScrollView {
                VStack(alignment: .leading, spacing: compactWidth ? Theme.spacingMD : Theme.spacingLG) {
                    header(compactWidth: compactWidth)
                    monthSummary(compactWidth: compactWidth)
                    calendarCard(compactWidth: compactWidth)
                }
                .padding(.horizontal, compactWidth ? Theme.spacingSM : Theme.spacingMD)
                .padding(.top, compactWidth ? Theme.spacingSM : Theme.spacingMD)
                .padding(.bottom, Theme.spacingXL)
            }
            .background(Theme.backgroundPrimary.ignoresSafeArea())
        }
        .sheet(item: Binding(
            get: {
                selectedDate.map(HistoryDaySelection.init)
            },
            set: { selection in
                selectedDate = selection?.date
            }
        )) { selection in
            HistoryDaySheet(viewModel: viewModel, date: selection.date)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    private func header(compactWidth: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            HStack(alignment: .top, spacing: Theme.spacingSM) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("History")
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)

                    Text("Calendar, day achievements, metrics, and QS edits")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                }

                if !compactWidth {
                    Spacer(minLength: Theme.spacingSM)
                    monthStepper
                }
            }

            if compactWidth {
                monthStepper
            }
        }
    }

    private var monthStepper: some View {
        HStack(spacing: Theme.spacingSM) {
            calendarStepButton(systemName: "chevron.left") {
                displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
            }

            Text(monthTitle(for: displayedMonth))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)

            calendarStepButton(systemName: "chevron.right") {
                displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
            }
        }
    }

    private func monthSummary(compactWidth: Bool) -> some View {
        let logs = logsForDisplayedMonth
        let adherence = StatsEngine.averageAdherence(from: logs)
        let commitment = StatsEngine.averageCommitment(from: logs)
        let qsDays = Set(viewModel.dataStore.qsRecords(inMonth: displayedMonth).map { Calendar.current.startOfDay(for: $0.date) }).count

        return LazyVGrid(columns: summaryColumns(compactWidth: compactWidth), spacing: Theme.spacingSM) {
            summaryCard(title: "Logged", value: "\(logs.count)", unit: "days", color: Theme.info, compactWidth: compactWidth)
            summaryCard(title: "Adherence", value: "\(Int((adherence * 100).rounded()))%", unit: "month", color: Theme.success, compactWidth: compactWidth)
            summaryCard(title: "QS", value: "\(qsDays)", unit: "days", color: Theme.warning, compactWidth: compactWidth)

            if viewModel.dataStore.qsEntries.contains(where: { $0.inputType == .text || $0.inputType == .journal || $0.inputType == .options || $0.inputType == .number || $0.inputType == .boolean || $0.inputType == .time }) {
                summaryCard(title: "Commit", value: "\(Int((commitment * 100).rounded()))%", unit: "month", color: Theme.warning, compactWidth: compactWidth)
            }
        }
    }

    private func calendarCard(compactWidth: Bool) -> some View {
        CueCard(padding: compactWidth ? Theme.spacingSM : Theme.spacingMD) {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                LazyVGrid(columns: dayColumns(compactWidth: compactWidth), spacing: compactWidth ? 4 : 8) {
                    ForEach(Calendar.current.veryShortWeekdaySymbols, id: \.self) { symbol in
                        Text(symbol.uppercased())
                            .font(.system(size: compactWidth ? 9 : 10, weight: .semibold))
                            .foregroundColor(Theme.textTertiary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(monthCells) { cell in
                        if let date = cell.date {
                            dayCell(for: date, isCurrentMonth: cell.isCurrentMonth, compactWidth: compactWidth)
                        } else {
                            Color.clear
                                .frame(height: compactWidth ? 48 : 58)
                        }
                    }
                }
            }
        }
    }

    private func dayCell(for date: Date, isCurrentMonth: Bool, compactWidth: Bool) -> some View {
        let log = viewModel.historyLog(for: date)
        let qsCount = viewModel.historyQSRecords(for: date).count
        let isToday = Calendar.current.isDateInToday(date)
        let selected = selectedDate.map { Calendar.current.isDate($0, inSameDayAs: date) } ?? false

        return Button {
            selectedDate = date
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: compactWidth ? 12 : 14, weight: .semibold, design: .rounded))
                        .foregroundColor(dayNumberColor(isCurrentMonth: isCurrentMonth, selected: selected))

                    Spacer(minLength: 0)

                    if isToday {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer(minLength: 0)

                if let log {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int((log.adherence * 100).rounded()))%")
                            .font(.system(size: compactWidth ? 10 : 11, weight: .bold, design: .monospaced))
                            .foregroundColor(selected ? Theme.selectionForeground : Theme.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)

                        Text(compactWidth ? "\(log.blockLogs.filter(\.wasChecked).count)d" : "\(log.blockLogs.filter(\.wasChecked).count) done")
                            .font(.system(size: compactWidth ? 8 : 9, weight: .medium))
                            .foregroundColor(selected ? Theme.selectionForeground.opacity(0.85) : Theme.textTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                } else if qsCount > 0 {
                    Text("QS \(qsCount)")
                        .font(.system(size: compactWidth ? 9 : 10, weight: .medium, design: .monospaced))
                        .foregroundColor(selected ? Theme.selectionForeground : Theme.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Text(" ")
                        .font(.system(size: 10))
                }
            }
            .padding(compactWidth ? 6 : 8)
            .frame(maxWidth: .infinity, minHeight: compactWidth ? 48 : 58, alignment: .topLeading)
            .background(dayBackground(log: log, qsCount: qsCount, selected: selected, isCurrentMonth: isCurrentMonth))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radiusSM)
                    .stroke(dayBorder(log: log, selected: selected), lineWidth: selected ? 1.4 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func calendarStepButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
                .frame(width: 28, height: 28)
                .background(Theme.backgroundCard)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private func summaryCard(title: String, value: String, unit: String, color: Color, compactWidth: Bool) -> some View {
        CueCard(padding: compactWidth ? Theme.spacingSM : Theme.spacingMD) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Theme.textTertiary)

                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.system(size: compactWidth ? 18 : 22, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(unit)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func summaryColumns(compactWidth: Bool) -> [GridItem] {
        let minimum: CGFloat = compactWidth ? 120 : 148
        return [GridItem(.adaptive(minimum: minimum, maximum: 220), spacing: Theme.spacingSM)]
    }

    private func dayColumns(compactWidth: Bool) -> [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 0), spacing: compactWidth ? 4 : 8), count: 7)
    }

    private var monthCells: [HistoryCalendarCell] {
        let calendar = Calendar.current
        let start = calendar.startOfMonth(for: displayedMonth)
        let firstWeekday = calendar.component(.weekday, from: start)
        let leadingBlanks = (firstWeekday - calendar.firstWeekday + 7) % 7
        let monthRange = calendar.range(of: .day, in: .month, for: start) ?? 1..<29
        let previousMonth = calendar.date(byAdding: .month, value: -1, to: start) ?? start
        let previousRange = calendar.range(of: .day, in: .month, for: previousMonth) ?? 1..<29

        var cells: [HistoryCalendarCell] = []

        for offset in 0..<leadingBlanks {
            let day = previousRange.count - leadingBlanks + offset + 1
            let date = calendar.date(bySetting: .day, value: day, of: previousMonth)
            cells.append(HistoryCalendarCell(date: date, isCurrentMonth: false))
        }

        for day in monthRange {
            let date = calendar.date(bySetting: .day, value: day, of: start)
            cells.append(HistoryCalendarCell(date: date, isCurrentMonth: true))
        }

        while cells.count % 7 != 0 {
            let nextOffset = cells.count - (leadingBlanks + monthRange.count) + 1
            let nextMonth = calendar.date(byAdding: .month, value: 1, to: start) ?? start
            let date = calendar.date(bySetting: .day, value: nextOffset, of: nextMonth)
            cells.append(HistoryCalendarCell(date: date, isCurrentMonth: false))
        }

        return cells
    }

    private var logsForDisplayedMonth: [DayLog] {
        let calendar = Calendar.current
        return viewModel.dataStore.dayLogs.filter {
            calendar.isDate($0.date, equalTo: displayedMonth, toGranularity: .month)
        }
    }

    private func monthTitle(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }

    private func dayNumberColor(isCurrentMonth: Bool, selected: Bool) -> Color {
        if selected { return Theme.selectionForeground }
        return isCurrentMonth ? Theme.textPrimary : Theme.textTertiary
    }

    private func dayBackground(log: DayLog?, qsCount: Int, selected: Bool, isCurrentMonth: Bool) -> Color {
        if selected { return Theme.selectionBackground }
        if let log {
            return log.adherence >= 0.8 ? Theme.success.opacity(0.16) : Theme.backgroundSecondary
        }
        if qsCount > 0 {
            return Theme.info.opacity(0.1)
        }
        return isCurrentMonth ? Theme.backgroundCard : Theme.backgroundSecondary
    }

    private func dayBorder(log: DayLog?, selected: Bool) -> Color {
        if selected { return Theme.accent }
        if let log, log.adherence > 0 {
            return Theme.success.opacity(0.25)
        }
        return Theme.backgroundTertiary
    }
}

private struct HistoryCalendarCell: Identifiable {
    let id = UUID()
    let date: Date?
    let isCurrentMonth: Bool
}

private struct HistoryDaySelection: Identifiable {
    let date: Date
    var id: Date {
        Calendar.current.startOfDay(for: date)
    }
}

private struct HistoryDaySheet: View {
    @ObservedObject var viewModel: MonitorViewModel
    let date: Date

    @Environment(\.dismiss) private var dismiss
    @State private var journalEntry: QSEntry?

    private var log: DayLog? {
        viewModel.historyLog(for: date)
    }

    private var records: [QSRecord] {
        viewModel.historyQSRecords(for: date)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    var body: some View {
        GeometryReader { proxy in
            let compactWidth = proxy.size.width < 370

            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: compactWidth ? Theme.spacingMD : Theme.spacingLG) {
                        headerCard(compactWidth: compactWidth)
                        if let log {
                            achievementsCard(log: log, compactWidth: compactWidth)
                        }
                        qsCard(compactWidth: compactWidth)
                        destructiveCard
                    }
                    .padding(compactWidth ? Theme.spacingSM : Theme.spacingMD)
                }
                .background(Theme.backgroundSecondary.ignoresSafeArea())
                .scrollIndicators(.hidden)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Close") { dismiss() }
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .sheet(item: $journalEntry) { entry in
                    JournalEditorView(viewModel: viewModel, entry: entry, date: date)
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    private func headerCard(compactWidth: Bool) -> some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                Text(formattedDate)
                    .font(Theme.heading3())
                    .foregroundColor(Theme.textPrimary)

                if let log {
                    LazyVGrid(columns: metricColumns(compactWidth: compactWidth), spacing: Theme.spacingSM) {
                        miniMetric(
                            title: "Formula",
                            value: log.formulaName.isEmpty ? "Untitled" : log.formulaName,
                            accent: Theme.info,
                            compactWidth: compactWidth
                        )
                        miniMetric(
                            title: "Adherence",
                            value: "\(Int((log.adherence * 100).rounded()))%",
                            accent: Theme.success,
                            compactWidth: compactWidth
                        )
                        miniMetric(
                            title: "Done",
                            value: "\(log.blockLogs.filter(\.wasChecked).count)/\(log.blockLogs.count)",
                            accent: Theme.warning,
                            compactWidth: compactWidth
                        )
                        miniMetric(
                            title: "Time",
                            value: StatsEngine.formatDuration(log.totalActualTime),
                            accent: Theme.textSecondary,
                            compactWidth: compactWidth
                        )

                        let commitment = StatsEngine.averageCommitment(from: [log])
                        if commitment > 0 {
                            miniMetric(
                                title: "Commitment",
                                value: "\(Int((commitment * 100).rounded()))%",
                                accent: Theme.warning,
                                compactWidth: compactWidth
                            )
                        }
                    }
                } else {
                    Text("No formula log saved for this day yet. You can still edit the QS data below.")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
    }

    private func achievementsCard(log: DayLog, compactWidth: Bool) -> some View {
        let completed = log.blockLogs.filter(\.wasChecked)

        return VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("Achievements")
                .font(Theme.heading3())
                .foregroundColor(Theme.textPrimary)

            if completed.isEmpty {
                CueCard {
                    Text("No completed blocks on this day.")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                }
            } else {
                ForEach(completed) { entry in
                    CueCard {
                        achievementRow(entry: entry, compactWidth: compactWidth)
                    }
                }
            }
        }
    }

    private func achievementRow(entry: BlockLogEntry, compactWidth: Bool) -> some View {
        Group {
            if compactWidth {
                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    HStack(spacing: Theme.spacingSM) {
                        Circle()
                            .fill(entry.category.color)
                            .frame(width: 10, height: 10)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(entry.blockName)
                                .font(Theme.body2())
                                .fontWeight(.semibold)
                                .foregroundColor(Theme.textPrimary)
                                .lineLimit(2)

                            Text(entry.subcategory.isEmpty ? entry.category.displayName : entry.subcategory)
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: Theme.spacingSM) {
                        Text(StatsEngine.formatDuration(entry.actualDuration))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)

                        if let rating = entry.commitmentRating {
                            Text("\(rating)/5")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.warning)
                        }
                    }
                }
            } else {
                HStack(spacing: Theme.spacingMD) {
                    Circle()
                        .fill(entry.category.color)
                        .frame(width: 10, height: 10)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(entry.blockName)
                            .font(Theme.body2())
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(2)

                        Text(entry.subcategory.isEmpty ? entry.category.displayName : entry.subcategory)
                            .font(.system(size: 11))
                            .foregroundColor(Theme.textTertiary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: Theme.spacingSM)

                    VStack(alignment: .trailing, spacing: 3) {
                        Text(StatsEngine.formatDuration(entry.actualDuration))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Theme.textSecondary)

                        if let rating = entry.commitmentRating {
                            Text("\(rating)/5")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(Theme.warning)
                        }
                    }
                }
            }
        }
    }

    private func qsCard(compactWidth: Bool) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingSM) {
            Text("Quantifiable Self")
                .font(Theme.heading3())
                .foregroundColor(Theme.textPrimary)

            if viewModel.dataStore.qsEntries.isEmpty {
                CueCard {
                    Text("No QS inputs configured yet.")
                        .font(Theme.caption())
                        .foregroundColor(Theme.textTertiary)
                }
            } else {
                ForEach(viewModel.dataStore.qsEntries) { entry in
                    CueCard {
                        qsRow(for: entry, compactWidth: compactWidth)
                    }
                }
            }
        }
    }

    private func qsRow(for entry: QSEntry, compactWidth: Bool) -> some View {
        Group {
            if compactWidth {
                VStack(alignment: .leading, spacing: Theme.spacingSM) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.name)
                            .font(Theme.body2())
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(2)

                        Text(entry.inputType.displayName)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }

                    historyInput(for: entry, compactWidth: compactWidth)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(spacing: Theme.spacingMD) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.name)
                            .font(Theme.body2())
                            .fontWeight(.semibold)
                            .foregroundColor(Theme.textPrimary)
                            .lineLimit(2)

                        Text(entry.inputType.displayName)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }

                    Spacer(minLength: Theme.spacingSM)

                    historyInput(for: entry, compactWidth: compactWidth)
                }
            }
        }
    }

    @ViewBuilder
    private func historyInput(for entry: QSEntry, compactWidth: Bool) -> some View {
        let currentValue = viewModel.historyQSValue(for: entry, on: date)

        switch entry.inputType {
        case .boolean:
            Toggle("", isOn: Binding(
                get: { currentValue == "true" },
                set: { viewModel.saveQSValue($0 ? "true" : "false", for: entry, on: date) }
            ))
            .labelsHidden()
            .tint(Theme.success)

        case .number:
            inputField(
                placeholder: "0",
                text: Binding(
                    get: { currentValue ?? "" },
                    set: { viewModel.saveQSValue($0, for: entry, on: date) }
                ),
                font: Theme.mono(),
                compactWidth: compactWidth,
                keyboardType: .decimalPad
            )

        case .text, .journal:
            Button {
                journalEntry = entry
            } label: {
                Text(currentValue == nil ? "Open Journal" : "Edit Journal")
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
                    Button(option) {
                        viewModel.saveQSValue(option, for: entry, on: date)
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
            inputField(
                placeholder: "07:30",
                text: Binding(
                    get: { currentValue ?? "" },
                    set: { viewModel.saveQSValue($0, for: entry, on: date) }
                ),
                font: Theme.mono(),
                compactWidth: compactWidth,
                keyboardType: .numbersAndPunctuation
            )
        }
    }

    private var destructiveCard: some View {
        Button {
            viewModel.removeHistory(for: date)
            dismiss()
        } label: {
            HStack {
                Spacer()
                Label("Clear This Day", systemImage: "trash")
                    .font(Theme.body2())
                    .foregroundColor(Theme.error)
                Spacer()
            }
            .padding(Theme.spacingMD)
            .background(Theme.error.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
        }
        .buttonStyle(.plain)
    }

    private func inputField(
        placeholder: String,
        text: Binding<String>,
        font: Font,
        compactWidth: Bool,
        keyboardType: UIKeyboardType
    ) -> some View {
        TextField(placeholder, text: text)
            .font(font)
            .foregroundColor(Theme.textPrimary)
            .keyboardType(keyboardType)
            .frame(maxWidth: compactWidth ? .infinity : 88, alignment: compactWidth ? .leading : .trailing)
            .multilineTextAlignment(compactWidth ? .leading : .trailing)
            .padding(Theme.spacingXS)
            .background(Theme.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
    }

    private func miniMetric(title: String, value: String, accent: Color, compactWidth: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textTertiary)

            Text(value)
                .font(.system(size: compactWidth ? 13 : 14, weight: .semibold, design: .rounded))
                .foregroundColor(accent)
                .lineLimit(compactWidth ? 2 : 1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.spacingSM)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
    }

    private func metricColumns(compactWidth: Bool) -> [GridItem] {
        [GridItem(.adaptive(minimum: compactWidth ? 120 : 150), spacing: Theme.spacingSM)]
    }
}

private extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        self.date(from: dateComponents([.year, .month], from: date)) ?? date
    }
}
