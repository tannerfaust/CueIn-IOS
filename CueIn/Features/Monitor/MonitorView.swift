//
//  MonitorView.swift
//  CueIn
//
//  Main Monitor tab — Stats / QS toggle. Neutral dark styling.
//

import SwiftUI

struct MonitorView: View {
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var viewModel: MonitorViewModel
    
    init(dataStore: DataStore) {
        _viewModel = StateObject(wrappedValue: MonitorViewModel(dataStore: dataStore))
    }
    
    var body: some View {
        ZStack {
            Theme.backgroundPrimary.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Monitor")
                        .font(Theme.heading1())
                        .foregroundColor(Theme.textPrimary)
                    
                    Spacer()
                    
                    HStack(spacing: 0) {
                        ForEach(MonitorViewModel.MonitorMode.allCases, id: \.self) { mode in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.mode = mode
                                }
                            }) {
                                Text(mode.rawValue)
                                    .font(Theme.caption())
                                    .fontWeight(.semibold)
                                    .foregroundColor(viewModel.mode == mode ? .white : Theme.textTertiary)
                                    .padding(.horizontal, Theme.spacingMD)
                                    .padding(.vertical, Theme.spacingSM)
                                    .background(
                                        viewModel.mode == mode
                                        ? Theme.backgroundElevated
                                        : Color.clear
                                    )
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .background(Theme.backgroundTertiary)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, Theme.spacingMD)
                .padding(.top, Theme.spacingSM)
                .padding(.bottom, Theme.spacingMD)
                
                ScrollView {
                    VStack(spacing: Theme.spacingLG) {
                        switch viewModel.mode {
                        case .stats:
                            StatsView(viewModel: viewModel)
                        case .qs:
                            QSView(viewModel: viewModel)
                        }
                    }
                    .padding(.horizontal, Theme.spacingMD)
                    .padding(.bottom, Theme.spacingXL)
                }
            }
        }
    }
}
