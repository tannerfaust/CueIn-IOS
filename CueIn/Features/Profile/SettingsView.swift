//
//  SettingsView.swift
//  CueIn
//
//  App settings — data management, auto-delete, reset.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var dataStore: DataStore
    @Environment(\.dismiss) private var dismiss
    
    @State private var showResetConfirm: Bool = false
    @State private var showDeleteAllConfirm: Bool = false
    @State private var autoDeleteDays: Int = 30
    
    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Nav bar
                HStack {
                    Button("Done") { dismiss() }
                        .foregroundColor(.white)
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
                                    .tint(.white)
                                }
                            }
                        }
                        .padding(.horizontal, Theme.spacingMD)
                        
                        // Explanation
                        infoRow("Goals, formulas, and week schedules are never auto-deleted")
                        infoRow("Day logs and QS journal entries follow the retention period")
                        
                        // MARK: - Reset Options
                        
                        sectionHeader("Reset")
                        
                        // Reset history (keep formulas)
                        Button {
                            showResetConfirm = true
                        } label: {
                            settingsRow(
                                icon: "arrow.counterclockwise",
                                title: "Reset History",
                                subtitle: "Deletes all day logs, QS records, and monitor data. Keeps formulas, schedule, goals, and profile.",
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
                                subtitle: "Removes everything — formulas, schedule, goals, history. App returns to fresh state.",
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
            Text("This will delete all day logs, QS records, and monitor data. Formulas, schedule, and goals will be kept.")
        }
        .alert("Delete All Data?", isPresented: $showDeleteAllConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Everything", role: .destructive) {
                dataStore.resetAll()
            }
        } message: {
            Text("This cannot be undone. All data will be permanently removed.")
        }
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
}
