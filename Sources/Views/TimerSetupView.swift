//
//  TimerSetupView.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//
import SwiftUI

struct TimerSetupView: View {
    @EnvironmentObject private var store: TimerStore

    // How many screen points the user must move to change 1 step.
    private let pixelsPerStep: CGFloat = 28

    // Internal accumulator so partial drags carry over during a gesture.
    @State private var dragAccumulator: CGFloat = 0
    @State private var showSettings = false

    private var minutes: Int { store.steps[store.selectedIndex] }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // 3) Center the main MM:SS UI
            VStack(spacing: 12) {
                Spacer(minLength: 0)

                TimeLabelView(minutes: minutes, seconds: 0)
                    .padding(.bottom, 4)

                Text("Slide up/down to set time")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                //#if DEBUG
                // Dev-only helpers to preview states
                //HStack(spacing: 12) {
                  //  Button("Preview Countdown") { store.goToCountdown() }
                  //  Button("Preview Run") { store.goToRunning() }
                  //  Button("Preview End") { store.goToEnded() }
                //}
                //.font(.footnote)
                //.tint(.white.opacity(0.9))
                //#endif

                Spacer(minLength: 0)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
        }
        .gesture(dragGesture)
        .onAppear { dragAccumulator = 0 }
        // 2) Gear in the left of the top nav bar (only on setup screen)
        .navigationTitle("") // no visible title
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 18, weight: .semibold))
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { value in
                if store.appState == .countingDown {
                    store.cancelCountdownAndReturnToIdle()
                } else {
                    store.cancelPendingStart()
                }

                let delta = -(value.translation.height) // up increases
                let effective = delta - dragAccumulator
                let stepsDelta = Int(effective / pixelsPerStep)

                if stepsDelta != 0 {
                    store.adjustIndex(by: stepsDelta)
                    dragAccumulator += CGFloat(stepsDelta) * pixelsPerStep
                }
            }
            .onEnded { _ in
                dragAccumulator = 0
                store.scheduleCountdownAfterInactivity()
            }
    }
}


