//
//  QSEntryEditorView.swift
//  CueIn
//
//  Editor for creating and updating QS inputs with presets and trigger controls.
//

import SwiftUI

private struct QSEntryDraft {
    var id: UUID?
    var name: String
    var inputType: QSInputType
    var trigger: QSTriggerSettings
    var automation: QSAutomation
    var optionsText: String
    var defaultTrue: Bool
    var icon: String

    init(entry: QSEntry? = nil) {
        id = entry?.id
        name = entry?.name ?? ""
        inputType = entry?.inputType ?? .number
        trigger = entry?.trigger ?? .none
        automation = entry?.automation ?? .proactive
        optionsText = entry?.options.joined(separator: "\n") ?? ""
        defaultTrue = entry?.defaultTrue ?? false
        icon = entry?.icon ?? "star"
    }

    var options: [String] {
        optionsText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    mutating func applyPreset(_ preset: QSPresetDefinition) {
        name = preset.entry.name
        inputType = preset.entry.inputType
        trigger = preset.entry.trigger
        automation = preset.entry.automation
        optionsText = preset.entry.options.joined(separator: "\n")
        defaultTrue = preset.entry.defaultTrue
        icon = preset.entry.icon
    }

    func makeEntry() -> QSEntry {
        QSEntry(
            id: id ?? UUID(),
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            inputType: inputType,
            trigger: trigger,
            automation: automation,
            options: options,
            defaultTrue: defaultTrue,
            icon: icon.isEmpty ? inputType.icon : icon
        )
    }
}

struct QSEntryEditorView: View {
    let entry: QSEntry?
    let onSave: (QSEntry) -> Void
    let onDelete: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var draft: QSEntryDraft
    @State private var showPresetLibrary = false

    init(entry: QSEntry?, onSave: @escaping (QSEntry) -> Void, onDelete: (() -> Void)? = nil) {
        self.entry = entry
        self.onSave = onSave
        self.onDelete = onDelete
        _draft = State(initialValue: QSEntryDraft(entry: entry))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundSecondary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        presetSection
                        detailsSection
                        triggerSection
                        if draft.inputType == .options {
                            optionsSection
                        }
                        if draft.inputType == .boolean {
                            booleanSection
                        }
                        if let onDelete {
                            deleteSection(onDelete: onDelete)
                        }
                    }
                    .padding(Theme.spacingMD)
                }
            }
            .navigationTitle(entry == nil ? "New Input" : "Edit Input")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft.makeEntry())
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showPresetLibrary) {
                QSPresetLibraryView { preset in
                    draft.applyPreset(preset)
                    showPresetLibrary = false
                }
            }
        }
    }

    private var presetSection: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Text("Preset Library")
                    .font(Theme.heading3())
                    .foregroundColor(Theme.textPrimary)

                Text("Start from a ready-made input instead of rebuilding common tracking rows every time.")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)

                Button {
                    showPresetLibrary = true
                } label: {
                    HStack {
                        Image(systemName: "square.grid.2x2")
                        Text("Browse Presets")
                    }
                    .font(Theme.body2())
                    .foregroundColor(Theme.selectionForeground)
                    .padding(.horizontal, Theme.spacingMD)
                    .padding(.vertical, Theme.spacingSM)
                    .background(Theme.selectionBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var detailsSection: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                Text("Details")
                    .font(Theme.heading3())
                    .foregroundColor(Theme.textPrimary)

                entryField(title: "Name") {
                    TextField("Input name", text: $draft.name)
                        .font(Theme.body1())
                        .foregroundColor(Theme.textPrimary)
                }

                entryField(title: "Type") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.spacingSM) {
                            ForEach(inputTypes, id: \.self) { type in
                                Button {
                                    draft.inputType = type
                                    if type != .options {
                                        draft.optionsText = ""
                                    }
                                } label: {
                                    Text(type.displayName)
                                        .font(Theme.caption())
                                        .fontWeight(.semibold)
                                        .foregroundColor(draft.inputType == type ? Theme.selectionForeground : Theme.textSecondary)
                                        .padding(.horizontal, Theme.spacingMD)
                                        .padding(.vertical, Theme.spacingSM)
                                        .background(draft.inputType == type ? Theme.selectionBackground : Theme.backgroundTertiary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                entryField(title: "Automation") {
                    Picker("", selection: $draft.automation) {
                        Text("Manual").tag(QSAutomation.proactive)
                        Text("Auto").tag(QSAutomation.automatic)
                    }
                    .pickerStyle(.segmented)
                }

                entryField(title: "Icon") {
                    TextField("SF Symbol", text: $draft.icon)
                        .font(Theme.body2())
                        .foregroundColor(Theme.textPrimary)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
            }
        }
    }

    private var triggerSection: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                Text("Reminder Trigger")
                    .font(Theme.heading3())
                    .foregroundColor(Theme.textPrimary)

                Toggle("Remind me for this input", isOn: Binding(
                    get: { draft.trigger.isEnabled },
                    set: { isOn in
                        draft.trigger.isEnabled = isOn
                        if !isOn {
                            draft.trigger.kind = .manual
                        } else if draft.trigger.kind == .manual {
                            draft.trigger.kind = draft.inputType == .journal ? .afterFinalBlock : .scheduledTime
                        }
                    }
                ))
                .tint(Theme.accent)

                if draft.trigger.isEnabled {
                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                        ForEach(triggerKinds(for: draft.inputType)) { kind in
                            Button {
                                draft.trigger.kind = kind
                            } label: {
                                HStack(alignment: .top, spacing: Theme.spacingSM) {
                                    Image(systemName: draft.trigger.kind == kind ? "largecircle.fill.circle" : "circle")
                                        .foregroundColor(draft.trigger.kind == kind ? Theme.accent : Theme.textTertiary)

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(kind.displayName)
                                            .font(Theme.body2())
                                            .foregroundColor(Theme.textPrimary)

                                        Text(kind.description)
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.textTertiary)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    if draft.trigger.kind == .scheduledTime {
                        DatePicker(
                            "Reminder Time",
                            selection: scheduledTimeBinding,
                            displayedComponents: .hourAndMinute
                        )
                        .datePickerStyle(.compact)
                        .tint(Theme.accent)
                    }
                }
            }
        }
    }

    private var optionsSection: some View {
        CueCard {
            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                Text("Options")
                    .font(Theme.heading3())
                    .foregroundColor(Theme.textPrimary)

                Text("One option per line. Keep them short so they read well in Today and History.")
                    .font(Theme.caption())
                    .foregroundColor(Theme.textTertiary)

                TextEditor(text: $draft.optionsText)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(Theme.spacingSM)
                    .background(Theme.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
                    .foregroundColor(Theme.textPrimary)
            }
        }
    }

    private var booleanSection: some View {
        CueCard {
            Toggle("Treat unchecked as the unusual case", isOn: $draft.defaultTrue)
                .tint(Theme.accent)
                .foregroundColor(Theme.textPrimary)
        }
    }

    private func deleteSection(onDelete: @escaping () -> Void) -> some View {
        Button(role: .destructive) {
            onDelete()
            dismiss()
        } label: {
            HStack {
                Spacer()
                Label("Delete Input", systemImage: "trash")
                    .font(Theme.body2())
                Spacer()
            }
            .padding(Theme.spacingMD)
            .background(Theme.error.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
        }
        .buttonStyle(.plain)
    }

    private func entryField<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.spacingXS) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Theme.textTertiary)

            content()
                .padding(Theme.spacingSM)
                .background(Theme.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
        }
    }

    private var inputTypes: [QSInputType] {
        [.number, .boolean, .time, .options, .journal, .text]
    }

    private func triggerKinds(for inputType: QSInputType) -> [QSTriggerKind] {
        switch inputType {
        case .journal:
            return [.scheduledTime, .formulaEnd, .afterFinalBlock]
        case .time:
            return [.scheduledTime, .formulaStart, .formulaEnd]
        default:
            return [.scheduledTime, .formulaStart, .formulaEnd, .afterFinalBlock]
        }
    }

    private var scheduledTimeBinding: Binding<Date> {
        Binding(
            get: {
                Calendar.current.startOfDay(for: Date()).addingTimeInterval(draft.trigger.scheduledSecondsFromMidnight)
            },
            set: { newDate in
                let startOfDay = Calendar.current.startOfDay(for: newDate)
                draft.trigger.scheduledSecondsFromMidnight = newDate.timeIntervalSince(startOfDay)
            }
        )
    }
}

struct QSPresetLibraryView: View {
    let onPick: (QSPresetDefinition) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.backgroundSecondary.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        ForEach(QSPresetLibrary.groupedPresets, id: \.category) { group in
                            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                                Text(group.category)
                                    .font(Theme.heading3())
                                    .foregroundColor(Theme.textPrimary)

                                ForEach(group.presets) { preset in
                                    Button {
                                        onPick(preset)
                                    } label: {
                                        CueCard {
                                            HStack(alignment: .top, spacing: Theme.spacingMD) {
                                                Image(systemName: preset.entry.icon)
                                                    .font(.system(size: 16))
                                                    .foregroundColor(Theme.textSecondary)
                                                    .frame(width: 34, height: 34)
                                                    .background(Theme.backgroundTertiary)
                                                    .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))

                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(preset.title)
                                                        .font(Theme.body2())
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(Theme.textPrimary)

                                                    Text(preset.subtitle)
                                                        .font(Theme.caption())
                                                        .foregroundColor(Theme.textTertiary)

                                                    Text(preset.entry.trigger.summary)
                                                        .font(.system(size: 10, weight: .semibold))
                                                        .foregroundColor(Theme.warning)
                                                }

                                                Spacer()
                                            }
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(Theme.spacingMD)
                }
            }
            .navigationTitle("Preset Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
