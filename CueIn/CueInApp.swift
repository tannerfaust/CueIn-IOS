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
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(dataStore)
                .preferredColorScheme(.dark)
                .onAppear {
                    // Auto-delete metrics older than 30 days
                    dataStore.autoDeleteOldMetrics(olderThan: 30)
                }
        }
    }
}
