import SwiftUI
import UIKit
import CoreData

struct RootView: View {
    @EnvironmentObject private var store: TimerStore
    @Environment(\.managedObjectContext) private var moc
    @Namespace private var countdownNS

    var body: some View {
        ZStack {
            // Idle / Setup
            if store.appState == .idle || store.appState == .ended {
                TimerSetupView(namespace: countdownNS)
                    .transition(.opacity) // calm fade
            }

            // Countdown over setup
            if store.appState == .countingDown {
                // Keep setup underneath; overlay centered countdown
                TimerSetupView(namespace: countdownNS)
                CountdownOverlay(number: store.countdownValue, namespace: countdownNS)
                    .transition(.opacity) // calm fade
            }

            // Running
            if store.appState == .running {
                FocusView(progress: store.progress, color: store.sessionColor)
                    .transition(.opacity) // calm fade
            }
        }
        .ignoresSafeArea()
        .statusBar(hidden: true)
        // IMPORTANT: avoid implicit animations on global state changes.
        // We'll use explicit withAnimation calls inside the store / actions instead.
        .animation(nil, value: store.appState)
        .onAppear {
            store.attach(context: moc)
            store.restoreIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            store.handleAppWillTerminate()
        }
    }
}
