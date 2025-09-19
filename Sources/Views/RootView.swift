import SwiftUI
import UIKit
import CoreData

struct RootView: View {
    @EnvironmentObject private var store: TimerStore
    @Environment(\.managedObjectContext) private var moc
    @Namespace private var countdownNS

    // Controls the fade-in of the setup view from black
    @State private var showSetupFade: Bool = false
    // Forces a fresh onAppear for Setup view whenever we re-enter idle
    @State private var idleToken = UUID()

    var body: some View {
        ZStack {
            // Solid black backplate—prevents any flash
            Color.black.ignoresSafeArea()

            // IDLE / SETUP: We render it with manual opacity control so it fades in from black
            if store.appState == .idle || store.appState == .ended {
                TimerSetupView(namespace: countdownNS)
                    .id(idleToken)                 // re-trigger onAppear per idle entry
                    .opacity(showSetupFade ? 1 : 0)
                    .onAppear {
                        // Start from black, then fade Setup in
                        showSetupFade = false
                        withAnimation(.easeInOut(duration: 0.35)) {
                            showSetupFade = true
                        }
                    }
            }

            // COUNTDOWN overlays the setup; calm fade (no slide/scale)
            if store.appState == .countingDown {
                TimerSetupView(namespace: countdownNS)
                CountdownOverlay(number: store.countdownValue, namespace: countdownNS)
                    .transition(.opacity)
            }

            // FOCUS running—calm fade
            if store.appState == .running {
                FocusView(progress: store.progress, color: store.sessionColor)
                    .transition(.opacity)
            }

            // BREAK running—calm fade; break drains color top→bottom
            if store.appState == .breakRunning {
                BreakView(progress: store.progress, color: store.sessionColor)
                    .transition(.opacity)
            }
        }
        .statusBar(hidden: true)
        // Avoid implicit container animations; we drive what we need explicitly
        .animation(nil, value: store.appState)
        .onAppear {
            store.attach(context: moc)
            store.restoreIfNeeded()

            // App launch: if we are in idle after restore, run the fade-in
            if store.appState == .idle || store.appState == .ended {
                idleToken = UUID()
                showSetupFade = false
                // Slight delay avoids racing first layout
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showSetupFade = true
                    }
                }
            }
        }
        // Whenever we *enter* idle (e.g., after break ends), re-run the fade
        .onChange(of: store.appState) { newValue in
            if newValue == .idle || newValue == .ended {
                idleToken = UUID()      // force SetupView .onAppear again
                showSetupFade = false
                DispatchQueue.main.async {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        showSetupFade = true
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willTerminateNotification)) { _ in
            store.handleAppWillTerminate()
        }
    }
}
