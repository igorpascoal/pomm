import UIKit

enum HapticsService {
    static func light() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.impactOccurred()
    }
    static func medium() {
        let g = UIImpactFeedbackGenerator(style: .medium)
        g.impactOccurred()
    }
    static func rigid() {
        let g = UIImpactFeedbackGenerator(style: .rigid)
        g.impactOccurred()
    }
    static func success() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }
    static func warning() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.warning)
    }
    static func error() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.error)
    }
}
