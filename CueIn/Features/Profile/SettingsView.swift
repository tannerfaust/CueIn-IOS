//
//  SettingsView.swift
//  CueIn
//
//  App settings — data management, auto-delete, reset.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var dataStore: DataStore
    @Binding var appearanceModeRawValue: String
    @AppStorage(TodayProgressDisplayMode.storageKey) private var todayProgressDisplayModeRawValue = TodayProgressDisplayMode.elapsed.rawValue
    @AppStorage(CommitmentRatingSetting.storageKey) private var isCommitmentRatingEnabled = CommitmentRatingSetting.defaultValue
    @AppStorage(ExecutionControlsSetting.storageKey) private var isExecutionControlsEnabled = ExecutionControlsSetting.defaultValue
    @AppStorage(TimeMagnetSetting.storageKey) private var isTimeMagnetEnabled = TimeMagnetSetting.defaultValue
    @AppStorage(ScheduleOverrunSetting.storageKey) private var expandsDayForOverrun = ScheduleOverrunSetting.defaultValue
    @AppStorage(IncompleteDayMetricsSetting.storageKey) private var savesMetricsWithoutCompletion = IncompleteDayMetricsSetting.defaultValue
    @AppStorage(OvertimeCheckInSetting.enabledStorageKey) private var isOvertimeCheckInEnabled = OvertimeCheckInSetting.defaultEnabled
    @AppStorage(OvertimeCheckInSetting.limitStorageKey) private var overtimeCheckInLimitSeconds = OvertimeCheckInSetting.defaultLimitSeconds
    @AppStorage(LazyStartSetting.enabledStorageKey) private var isLazyStartEnabled = LazyStartSetting.defaultEnabled
    @AppStorage(LazyStartSetting.thresholdStorageKey) private var lazyStartThresholdSeconds = LazyStartSetting.defaultThresholdSeconds
    @Environment(\.dismiss) private var dismiss
    
    @State private var showResetConfirm: Bool = false
    @State private var showDeleteAllConfirm: Bool = false
    @State private var showInstallSamplesConfirm: Bool = false
    @State private var autoDeleteDays: Int = 30

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }
    
    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.accent)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text("Settings")
                        .font(Theme.heading3())
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    // Invisible spacer for centering
                    Text("Done").opacity(0)
                }
                .padding(Theme.spacingMD)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: Theme.spacingLG) {
                        
                        // MARK: - Data Retention

                        sectionHeader("Appearance")

                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                                Text("Theme")
                                    .font(Theme.body1())
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.textPrimary)

                                HStack(spacing: Theme.spacingSM) {
                                    ForEach(AppearanceMode.allCases) { mode in
                                        Button {
                                            appearanceModeRawValue = mode.rawValue
                                        } label: {
                                            Text(mode.title)
                                                .font(Theme.caption())
                                                .fontWeight(.semibold)
                                                .foregroundColor(
                                                    appearanceModeRawValue == mode.rawValue
                                                    ? Theme.selectionForeground
                                                    : Theme.textSecondary
                                                )
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, Theme.spacingSM)
                                                .background(
                                                    appearanceModeRawValue == mode.rawValue
                                                    ? Theme.selectionBackground
                                                    : Theme.backgroundTertiary
                                                )
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                Text("System follows the device setting. Light uses off-white surfaces with preserved contrast.")
                                    .font(Theme.caption())
                                    .foregroundColor(Theme.textTertiary)
                                    .lineSpacing(2)
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)

                        sectionHeader("Today")

                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                                Text("Progress Percentage")
                                    .font(Theme.body1())
                                    .fontWeight(.medium)
                                    .foregroundColor(Theme.textPrimary)

                                HStack(spacing: Theme.spacingSM) {
                                    ForEach(TodayProgressDisplayMode.allCases) { mode in
                                        Button {
                                            todayProgressDisplayModeRawValue = mode.rawValue
                                        } label: {
                                            Text(mode.title)
                                                .font(Theme.caption())
                                                .fontWeight(.semibold)
                                                .foregroundColor(
                                                    todayProgressDisplayModeRawValue == mode.rawValue
                                                    ? Theme.selectionForeground
                                                    : Theme.textSecondary
                                                )
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, Theme.spacingSM)
                                                .background(
                                                    todayProgressDisplayModeRawValue == mode.rawValue
                                                    ? Theme.selectionBackground
                                                    : Theme.backgroundTertiary
                                                )
                                                .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                Text("Choose whether Today shows how much of the day has passed or how much is left. Completion percentage still shows how much of the planned day you finished.")
                                    .font(Theme.caption())
                                    .foregroundColor(Theme.textTertiary)
                                    .lineSpacing(2)
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)

                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Commitment Rating")
                                            .font(Theme.body1())
                                            .fontWeight(.medium)
                                            .foregroundColor(Theme.textPrimary)

                                        Text("Show star ratings on completed blocks and add commitment metrics to Monitor.")
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.textTertiary)
                                            .lineSpacing(2)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $isCommitmentRatingEnabled)
                                        .labelsHidden()
                                        .tint(Theme.accent)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)

                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Execution Controls")
                                            .font(Theme.body1())
                                            .fontWeight(.medium)
                                            .foregroundColor(Theme.textPrimary)

                                        Text("Show the execution-mode button and per-block play controls on Today. Turn this off if you want a calmer, less busy schedule view.")
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.textTertiary)
                                            .lineSpacing(2)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $isExecutionControlsEnabled)
                                        .labelsHidden()
                                        .tint(Theme.accent)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)

                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Keep Original Block Times")
                                            .font(Theme.body1())
                                            .fontWeight(.medium)
                                            .foregroundColor(Theme.textPrimary)

                                        Text("If the current block runs long, expand the whole day instead of shrinking the rest of the schedule to fit the old timeframe.")
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.textTertiary)
                                            .lineSpacing(2)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $expandsDayForOverrun)
                                        .labelsHidden()
                                        .tint(Theme.accent)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)

                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Save Metrics Without Completion")
                                            .font(Theme.body1())
                                            .fontWeight(.medium)
                                            .foregroundColor(Theme.textPrimary)

                                        Text("Save the day into metrics even if you clear Today early, reset it, or come back after abandoning the run.")
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.textTertiary)
                                            .lineSpacing(2)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $savesMetricsWithoutCompletion)
                                        .labelsHidden()
                                        .tint(Theme.accent)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)

                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Overtime Check-In")
                                            .font(Theme.body1())
                                            .fontWeight(.medium)
                                            .foregroundColor(Theme.textPrimary)

                                        Text("If the current block goes past its planned time by the chosen limit, Today pauses it and sends “Are you still here?”.")
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.textTertiary)
                                            .lineSpacing(2)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $isOvertimeCheckInEnabled)
                                        .labelsHidden()
                                        .tint(Theme.accent)
                                }

                                if isOvertimeCheckInEnabled {
                                    VStack(alignment: .leading, spacing: Theme.spacingSM) {
                                        Text("Pause after overtime")
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.textTertiary)

                                        HStack(spacing: Theme.spacingSM) {
                                            ForEach(OvertimeCheckInSetting.limitOptions, id: \.self) { option in
                                                Button {
                                                    overtimeCheckInLimitSeconds = option
                                                } label: {
                                                    Text(OvertimeCheckInSetting.title(for: option))
                                                        .font(Theme.caption())
                                                        .fontWeight(.semibold)
                                                        .foregroundColor(
                                                            overtimeCheckInLimitSeconds == option
                                                            ? Theme.selectionForeground
                                                            : Theme.textSecondary
                                                        )
                                                        .frame(maxWidth: .infinity)
                                                        .padding(.vertical, Theme.spacingSM)
                                                        .background(
                                                            overtimeCheckInLimitSeconds == option
                                                            ? Theme.selectionBackground
                                                            : Theme.backgroundTertiary
                                                        )
                                                        .clipShape(Capsule())
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)

                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Lazy Start Quiz")
                                            .font(Theme.body1())
                                            .fontWeight(.medium)
                                            .foregroundColor(Theme.textPrimary)

                                        Text("If you start after the threshold time, Today asks when the schedule should end and recalibrates the formula to fit.")
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.textTertiary)
                                            .lineSpacing(2)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $isLazyStartEnabled)
                                        .labelsHidden()
                                        .tint(Theme.accent)
                                }

                                if isLazyStartEnabled {
                                    DatePicker(
                                        "Prompt after",
                                        selection: lazyStartThresholdDateBinding,
                                        displayedComponents: .hourAndMinute
                                    )
                                    .datePickerStyle(.compact)
                                    .foregroundColor(Theme.textPrimary)
                                    .tint(Theme.accent)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)

                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Time Magnet")
                                            .font(Theme.body1())
                                            .fontWeight(.medium)
                                            .foregroundColor(Theme.textPrimary)

                                        Text("App-wide switch for magnetized schedule snapping. Each full formula can still turn its own magnet on or off from the three-dot menu in the formula editor or Today.")
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.textTertiary)
                                            .lineSpacing(2)
                                    }

                                    Spacer()

                                    Toggle("", isOn: $isTimeMagnetEnabled)
                                        .labelsHidden()
                                        .tint(Theme.accent)
                                }

                                Text(timeMagnetStatusText)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)
                        
                        sectionHeader("Data Retention")
                        
                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingMD) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Auto-delete metrics")
                                            .font(Theme.body1())
                                            .fontWeight(.medium)
                                            .foregroundColor(Theme.textPrimary)
                                        
                                        Text("Day logs and QS records older than \(autoDeleteDays) days are automatically removed. Goals are never deleted.")
                                            .font(Theme.caption())
                                            .foregroundColor(Theme.textTertiary)
                                            .lineSpacing(2)
                                    }
                                    
                                    Spacer()
                                }
                                
                                HStack {
                                    Text("\(autoDeleteDays) days")
                                        .font(Theme.mono())
                                        .foregroundColor(Theme.textPrimary)
                                        .frame(width: 70, alignment: .leading)
                                    
                                    Slider(value: Binding(
                                        get: { Double(autoDeleteDays) },
                                        set: { autoDeleteDays = Int($0) }
                                    ), in: 7...90, step: 1)
                                    .tint(Theme.accent)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)
                        
                        // Explanation
                        infoRow("Goals, formulas, and week schedules are never auto-deleted")
                        infoRow("Day logs and QS journal entries follow the retention period")
                        
                        // MARK: - Reset Options
                        
                        sectionHeader("Reset")

                        Button {
                            showInstallSamplesConfirm = true
                        } label: {
                            settingsRow(
                                icon: "shippingbox.fill",
                                title: "Load Testing Samples",
                                subtitle: "Adds ready-made formulas, mini-formulas, schedule defaults, QS entries, and sample logs for faster testing.",
                                color: Theme.categoryStudy
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Theme.spacingMD)
                        
                        // Reset history (keep formulas)
                        Button {
                            showResetConfirm = true
                        } label: {
                            settingsRow(
                                icon: "arrow.counterclockwise",
                                title: "Reset History",
                                subtitle: "Deletes all day logs, QS records, and monitor data. Keeps formulas, schedule, surges, and profile.",
                                color: Theme.warning
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Theme.spacingMD)
                        
                        // Delete everything
                        Button {
                            showDeleteAllConfirm = true
                        } label: {
                            settingsRow(
                                icon: "trash",
                                title: "Delete All Data",
                                subtitle: "Removes everything — formulas, schedule, surges, history. App returns to fresh state.",
                                color: Theme.error
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, Theme.spacingMD)
                        
                        // MARK: - About
                        
                        sectionHeader("About")
                        
                        CueCard {
                            VStack(alignment: .leading, spacing: Theme.spacingSM) {
                                HStack {
                                    Text("CueIn")
                                        .font(Theme.body1())
                                        .fontWeight(.medium)
                                        .foregroundColor(Theme.textPrimary)
                                    Spacer()
                                    Text("v1.1")
                                        .font(Theme.caption())
                                        .foregroundColor(Theme.textTertiary)
                                }
                                
                                Text("A personal time-flow system for structured, intentional days.")
                                    .font(Theme.caption())
                                    .foregroundColor(Theme.textTertiary)
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)
                    }
                    .padding(.bottom, Theme.spacingXL)
                }
            }
        }
        .alert("Reset History?", isPresented: $showResetConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Reset", role: .destructive) {
                dataStore.resetHistory()
            }
        } message: {
            Text("This will delete all day logs, QS records, and monitor data. Formulas, schedule, and surges will be kept.")
        }
        .alert("Load Testing Samples?", isPresented: $showInstallSamplesConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Load") {
                dataStore.installTestingSamples()
            }
        } message: {
            Text("This adds or refreshes the built-in sample formulas, mini-formulas, schedule defaults, QS entries, and sample logs without duplicating them.")
        }
        .alert("Delete All Data?", isPresented: $showDeleteAllConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                dataStore.resetAll()
            }
        } message: {
            Text("This cannot be undone. All data will be permanently removed.")
        }
        .preferredColorScheme(appearanceMode.preferredColorScheme)
    }
    
    // MARK: - Helpers
    
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(Theme.caption())
            .foregroundColor(Theme.textTertiary)
            .textCase(.uppercase)
            .padding(.horizontal, Theme.spacingMD)
            .padding(.top, Theme.spacingSM)
    }
    
    private func settingsRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: Theme.spacingMD) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
                .frame(width: 32, height: 32)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Theme.radiusSM))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(Theme.body1())
                    .fontWeight(.medium)
                    .foregroundColor(Theme.textPrimary)
                
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .lineSpacing(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(Theme.spacingMD)
        .background(Theme.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusMD))
    }
    
    private func infoRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.spacingSM) {
            Text("•")
                .font(.system(size: 10))
                .foregroundColor(Theme.textTertiary)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(Theme.textTertiary)
        }
        .padding(.horizontal, Theme.spacingMD)
    }

    private var lazyStartThresholdDateBinding: Binding<Date> {
        Binding(
            get: {
                let now = Date()
                let startOfDay = Calendar.current.startOfDay(for: now)
                return startOfDay.addingTimeInterval(lazyStartThresholdSeconds)
            },
            set: { newValue in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newValue)
                let hours = Double(components.hour ?? 0)
                let minutes = Double(components.minute ?? 0)
                lazyStartThresholdSeconds = (hours * 3600) + (minutes * 60)
            }
        )
    }

    private var timeMagnetStatusText: String {
        let enabledCount = dataStore.formulas.filter { $0.type == .full && $0.timeMagnet.isEnabled }.count
        let globalPrefix = isTimeMagnetEnabled ? "app on" : "app off"
        return enabledCount == 0
            ? "\(globalPrefix) • 0 full formulas configured"
            : "\(globalPrefix) • \(enabledCount) full formulas configured"
    }
}
