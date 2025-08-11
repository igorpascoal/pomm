//
//  CountdownOverlay.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//
import SwiftUI

struct CountdownOverlay: View {
    let number: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
            LargeNumberOverlay(value: number)
        }
        .ignoresSafeArea()
        .transition(.opacity)
    }
}

