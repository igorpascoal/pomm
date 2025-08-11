//
//  EndView.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//
import SwiftUI

struct EndView: View {
    @EnvironmentObject private var store: TimerStore

    var body: some View {
        ZStack {
            Color.black
            Button {
                store.reset()
            } label: {
                Text("Stop Focus Timer")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(Capsule())
            }
        }
        .foregroundStyle(.white)
        .ignoresSafeArea()
    }
}

