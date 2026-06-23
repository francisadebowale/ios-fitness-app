import SwiftUI

struct NutritionIntFieldRow<Field: Hashable>: View {
    let title: String
    let unit: String
    @Binding var value: Int
    let field: Field
    var focusedField: FocusState<Field?>.Binding

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .nutritionKeyboard(.number)
                .focused(focusedField, equals: field)
                .frame(minWidth: 72)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}

struct NutritionDoubleFieldRow<Field: Hashable>: View {
    let title: String
    let unit: String
    @Binding var value: Double
    let field: Field
    var focusedField: FocusState<Field?>.Binding

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title, value: $value, format: .number)
                .multilineTextAlignment(.trailing)
                .nutritionKeyboard(.decimal)
                .focused(focusedField, equals: field)
                .frame(minWidth: 72)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }
}
