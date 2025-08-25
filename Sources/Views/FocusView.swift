import SwiftUI
import UIKit

struct FocusView: View {
    @EnvironmentObject private var store: TimerStore
    @AppStorage("showTimeWhileRunning") private var showTimeWhileRunning: Bool = false
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = true

    let progress: CGFloat   // 0...1
    let color: Color
    @State private var showStop = false

    private var remaining: (Int, Int) {
        let s = max(0, store.remainingSeconds)
        return (s / 60, s % 60)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background with color fill
                ZStack(alignment: .bottom) {
                    Color.black
                    color
                        .frame(height: geo.size.height * max(0, min(1, progress)))
                        .frame(maxWidth: .infinity, alignment: .bottom)
                        .animation(.linear(duration: 0.0), value: progress)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                        showStop = true
                    }
                }

                // Remaining time (centered)
                if showTimeWhileRunning {
                    VStack {
                        Spacer()
                        TimeLabelView(minutes: remaining.0, seconds: remaining.1)
                            .font(.system(size: 140, weight: .semibold, design: .rounded))
                            .baselineOffset(-6)
                        Spacer()
                    }
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: showTimeWhileRunning)
                }

                // Stop button
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
                        store.cancelRunAndReturnToSetup()
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
        }
        .foregroundStyle(.white)
        .ignoresSafeArea()
        .onAppear { UIApplication.shared.isIdleTimerDisabled = keepScreenOn }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onChange(of: keepScreenOn) { newValue in
            UIApplication.shared.isIdleTimerDisabled = newValue
        }
    }
}
