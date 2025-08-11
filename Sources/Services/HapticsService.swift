//
//  HapticsService.swift
//  Pomm
//
//  Created by Igor Pascoal on 10/08/2025.
//
import UIKit

enum HapticsService {
    static func light() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

