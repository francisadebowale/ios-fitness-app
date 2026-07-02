import SwiftUI

struct SavedMealFormView: View {
    var body: some View {
        Form {
            TextField("Name", text: .constant(""))
            Text("Saved meal nutrition")
        }
    }
}
