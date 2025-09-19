import SwiftUI
import UIKit

struct BreakView: View {
    @EnvironmentObject private var store: TimerStore
    @AppStorage("showBreakCountdown") private var showBreakCountdown: Bool = false
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = true

    /// Break progress 0...1 (0 = full color; 1 = fully drained to black)
    let progress: CGFloat
    let color: Color

    @State private var showStop = false

    private var remaining: (Int, Int) {
        let s = max(0, store.remainingSeconds)
        return (s / 60, s % 60)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Base black background
                Color.black

                // Full-bleed color masked by a top-aligned rectangle whose height shrinks with progress.
                // This guarantees a *top→bottom* drain (mirror of focus bottom→top fill).
                color
                    .ignoresSafeArea()
                    .mask(
                        VStack(spacing: 0) {
                            Rectangle()
                                .frame(height: geo.size.height * max(0, 1 - progress))
                            Spacer(minLength: 0)
                        }
                    )
                    .animation(.easeInOut(duration: 0.12), value: progress)

                // Optional center countdown during break
                if showBreakCountdown {
                    VStack {
                        Spacer()
                        TimeLabelView(minutes: remaining.0, seconds: remaining.1)
                            .font(.system(size: 140, weight: .semibold, design: .rounded))
                            .baselineOffset(-6)
                        Spacer()
                    }
                    .transition(.opacity)
                }

                // Stop overlay (no scrim; tap outside to dismiss)
                if showStop {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                                showStop = false
                            }
                        }
                        .ignoresSafeArea()

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                            showStop = false
                        }
                        store.skipBreakAndReturnToSetup()
                    } label: {
                        Text("Stop")
                            .font(.system(size: 24, weight: .semibold, design: .rounded))
                            .frame(minWidth: 220)
                            .padding(.vertical, 16)
                            .background(.white)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                            .shadow(radius: 6, y: 2)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.9).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                HapticsService.light()
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    showStop = true
                }
            }
        }
        .foregroundStyle(.white)
        .ignoresSafeArea()
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepScreenOn }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: keepScreenOn) { UIApplication.shared.isIdleTimerDisabled = $0 }
    }
}
