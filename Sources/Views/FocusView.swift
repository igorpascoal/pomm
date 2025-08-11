//
//  FocusView.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//
import SwiftUI

struct FocusView: View {
    @EnvironmentObject private var store: TimerStore
    @AppStorage("showTimeWhileRunning") private var showTimeWhileRunning: Bool = false

    let progress: CGFloat   // 0...1
    let color: Color

    private var remainingMinutesSeconds: (Int, Int) {
        let s = max(0, store.remainingSeconds)
        return (s / 60, s % 60)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                Color.black

                color
                    .frame(height: geo.size.height * max(0, min(1, progress)))
                    .frame(maxWidth: .infinity, alignment: .bottom)
                    .animation(.linear(duration: 0.0), value: progress)

                if showTimeWhileRunning {
                    VStack {
                        Spacer(minLength: 0)
                        TimeLabelView(
                            minutes: remainingMinutesSeconds.0,
                            seconds: remainingMinutesSeconds.1
                        )
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .ignoresSafeArea()
    }
}

