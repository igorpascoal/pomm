import SwiftUI

struct CountdownOverlay: View {
    let number: Int
    let namespace: Namespace.ID
    @State private var tickScale: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Full-screen center
            VStack {
                Spacer()
                LargeNumberOverlay(value: number)
                    .font(.system(size: 140, weight: .semibold, design: .rounded))
                    .baselineOffset(-6)
                    .multilineTextAlignment(.center)
                    .matchedGeometryEffect(
                        id: "countdownMorph",
                        in: namespace,
                        properties: .size,       // <— only size, not position
                        anchor: .center,
                        isSource: true
                    )
                    .scaleEffect(tickScale)      // gentle "pop" per tick
                    .transition(.opacity)
                    .onAppear { bump() }
                    .onChange(of: number) { _ in bump() }
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.18), value: number)
    }

    private func bump() {
        tickScale = 1.0
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) { tickScale = 1.08 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.9)) { tickScale = 1.0 }
        }
    }
}
