//
//  MainTabView.swift
//  CueIn
//
//  Bottom tab bar with 4 main tabs.
//

import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var dataStore: DataStore
    @Binding var appearanceModeRawValue: String
    @State private var selectedTab: Tab = .today
    @StateObject private var formulaEngine = FormulaEngine()
    @StateObject private var qsTriggerScheduler = QSTriggerScheduler()
    
    enum Tab: String, CaseIterable {
        case today = "Today"
        case monitor = "Monitor"
        case lab = "Lab"
        case profile = "Profile"
        
        var icon: String {
            switch self {
            case .today:   return "sun.max.fill"
            case .lab:     return "flask.fill"
            case .monitor: return "chart.bar.fill"
            case .profile: return "person.fill"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab Content
            Group {
                switch selectedTab {
                case .today:
                    TodayView(dataStore: dataStore, engine: formulaEngine)
                case .monitor:
                    MonitorView(dataStore: dataStore, engine: formulaEngine)
                case .lab:
                    LabView(dataStore: dataStore, engine: formulaEngine)
                case .profile:
                    ProfileView(
                        dataStore: dataStore,
                        appearanceModeRawValue: $appearanceModeRawValue,
                        engine: formulaEngine
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 70)
            
            // Custom Tab Bar
            customTabBar
        }
        .ignoresSafeArea(.keyboard)
        .onAppear {
            qsTriggerScheduler.bind(dataStore: dataStore, engine: formulaEngine)
        }
    }
    
    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 18, weight: selectedTab == tab ? .bold : .regular))
                            .foregroundColor(selectedTab == tab ? Theme.accent : Theme.textTertiary)
                            .scaleEffect(selectedTab == tab ? 1.1 : 1.0)
                        
                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(selectedTab == tab ? Theme.accent : Theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Rectangle()
                        .fill(Theme.tabBarOverlay)
                )
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.tabBarHairline)
                        .frame(height: 0.5)
                }
        )
    }
}
