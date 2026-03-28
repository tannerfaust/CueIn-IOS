//
//  CueInApp.swift
//  CueIn
//
//  Created by Tanner Fause on 19.03.2026.
//

import SwiftUI

@main
struct CueInApp: App {
    @StateObject private var dataStore = DataStore()
    @AppStorage(AppearanceMode.storageKey) private var appearanceModeRawValue = AppearanceMode.system.rawValue

    private var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRawValue) ?? .system
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView(appearanceModeRawValue: $appearanceModeRawValue)
                .environmentObject(dataStore)
                .preferredColorScheme(appearanceMode.preferredColorScheme)
                .onAppear {
                    // Auto-delete metrics older than 30 days
                    dataStore.autoDeleteOldMetrics(olderThan: 30)
                }
        }
    }
}
