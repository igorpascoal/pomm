import SwiftUI

struct TimerSetupView: View {
    @EnvironmentObject private var store: TimerStore
    let namespace: Namespace.ID

    private let pixelsPerStep: CGFloat = 36
    @State private var dragAccumulator: CGFloat = 0
    @State private var showSettings = false

    private var minutes: Int { store.steps[store.selectedIndex] }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                VStack {
                    Spacer()

                    // Timer display optically centered
                    TimeLabelView(minutes: minutes, seconds: 0)
                        .font(.system(size: 140, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.5)
                        .baselineOffset(-6)
                        .frame(maxWidth: .infinity)
                        .frame(height: geo.size.height * 0.4) // ensures stable space
                        .matchedGeometryEffect(id: "countdownMorph", in: namespace)
                        .opacity(store.appState == .countingDown ? 0 : 1)
                        .animation(.easeInOut(duration: 0.25), value: store.appState)

                    Spacer()

                    if store.appState != .countingDown {
                        VStack(spacing: 18) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    store.userTappedStart()
                                }
                            } label: {
                                Text("Start")
                                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                                    .frame(minWidth: 180)
                                    .padding(.vertical, 16)
                                    .background(.white)
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }

                            Button {
                                showSettings = true
                            } label: {
                                Label("Settings", systemImage: "gearshape")
                                    .font(.callout)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.bottom, 40)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: store.appState)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
        .contentShape(Rectangle())
        .gesture(dragGesture)
        .onTapGesture {
            if store.appState == .countingDown {
                withAnimation(.easeInOut(duration: 0.25)) {
                    store.cancelCountdownAndReturnToIdle()
                }
            }
        }
        .onAppear { dragAccumulator = 0 }
        .sheet(isPresented: $showSettings) { SettingsView() }
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .onChanged { value in
                if store.appState == .countingDown {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        store.cancelCountdownAndReturnToIdle()
                    }
                }
                let delta = -(value.translation.height)
                let effective = delta - dragAccumulator
                let stepsDelta = Int(effective / pixelsPerStep)
                if stepsDelta != 0 {
                    store.adjustIndex(by: stepsDelta)
                    dragAccumulator += CGFloat(stepsDelta) * pixelsPerStep
                }
            }
            .onEnded { _ in dragAccumulator = 0 }
    }
}
