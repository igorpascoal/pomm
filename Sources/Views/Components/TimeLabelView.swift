//
//  TimeLabelView.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//
import SwiftUI

struct TimeLabelView: View {
    let minutes: Int
    let seconds: Int

    var body: some View {
        Text(String(format: "%02d:%02d", minutes, seconds))
            .font(.system(size: 72, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .accessibilityLabel("\(minutes) minutes \(seconds) seconds")
    }
}

