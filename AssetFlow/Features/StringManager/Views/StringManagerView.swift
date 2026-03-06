import SwiftUI

struct StringManagerView: View {
    var body: some View {
        ContentUnavailableView(
            "String Manager",
            systemImage: "character.bubble",
            description: Text("Manage localizable strings across multiple languages in one place.")
        )
    }
}
