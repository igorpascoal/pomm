import SwiftUI

struct CountdownOverlay: View {
    let number: Int
    let namespace: Namespace.ID

    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()

                LargeNumberOverlay(value: number)
                    .font(.system(size: 140, weight: .semibold, design: .rounded))
                    .baselineOffset(-6)
                    .frame(maxWidth: .infinity)
                    .frame(height: geo.size.height * 0.4)
                    .multilineTextAlignment(.center)
                    .matchedGeometryEffect(id: "countdownMorph", in: namespace)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: number)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
    }
}
