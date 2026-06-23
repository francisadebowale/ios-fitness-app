import SwiftUI

#if os(iOS)
import UIKit
#endif

enum NutritionKeyboard {
    case number
    case decimal
}

extension View {
    @ViewBuilder
    func nutritionKeyboard(_ keyboard: NutritionKeyboard) -> some View {
#if os(iOS)
        switch keyboard {
        case .number:
            keyboardType(.numberPad)
        case .decimal:
            keyboardType(.decimalPad)
        }
#else
        self
#endif
    }
}
