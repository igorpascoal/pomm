//
//  LargeNumberOverlay.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//
import SwiftUI

struct LargeNumberOverlay: View {
    let value: Int

    var body: some View {
        Text("\(value)")
            .font(.system(size: 120, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .shadow(radius: 8)
    }
}

