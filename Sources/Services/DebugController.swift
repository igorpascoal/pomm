import Foundation
import SwiftUI

@MainActor
final class DebugController: ObservableObject {
    static let shared = DebugController()

    // Ephemeral—reset on app relaunch
    @Published var isUnlocked: Bool = false
    @Published var accelerate: Bool = false
    @Published var speed: Speed = .x1

    enum Speed: String, CaseIterable, Identifiable {
        case x1 = "1×"
        case x2 = "2×"
        case x5 = "5×"
        case x10 = "10×"
        var id: String { rawValue }

        /// Multiplier compresses wall time (e.g., 2× => 0.5 real-time duration).
        var multiplier: Double {
            switch self {
            case .x1:  return 1.0
            case .x2:  return 0.5
            case .x5:  return 0.2
            case .x10: return 0.1
            }
        }
    }

    /// Effective multiplier the app should use everywhere for timing.
    var effectiveMultiplier: Double {
        (isUnlocked && accelerate) ? speed.multiplier : 1.0
    }

    func resetEphemeral() {
        isUnlocked = false
        accelerate = false
        speed = .x1
    }
}
