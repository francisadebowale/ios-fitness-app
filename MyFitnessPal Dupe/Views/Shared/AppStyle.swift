import SwiftUI

#if os(iOS)
import UIKit
#endif

enum MacroColor {
    static let calories = Color.orange
    static let protein = Color.blue
    static let carbs = Color.green
    static let fat = Color.pink
}

enum AppHaptics {
    static func lightImpact() {
#if os(iOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
#endif
    }

    static func success() {
#if os(iOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
#endif
    }
}
