//
//  RootView.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//
import SwiftUI
import UIKit
import CoreData

struct RootView: View {
    @EnvironmentObject private var store: TimerStore
    @Environment(\.managedObjectContext) private var moc

    var body: some View {
        Group {
            switch store.appState {
            case .idle, .countingDown:
                // Only the setup screen lives in a NavigationStack (for the top-left gear).
                NavigationStack {
                    ZStack {
                        TimerSetupView()
                        if store.appState == .countingDown {
                            CountdownOverlay(number: store.countdownValue)
                        }
                    }
                }
                .tint(.white) // white gear on black bg

            case .running:
                FocusView(progress: store.progress, color: store.sessionColor)

            case .ended:
                EndView()
            }
        }
        .ignoresSafeArea()                // full-bleed black background
        .statusBar(hidden: true)          // 1) never show status bar
        .onAppear {
            store.attach(context: moc)
            store.restoreIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            store.handleAppWillTerminate()
        }
    }
}
