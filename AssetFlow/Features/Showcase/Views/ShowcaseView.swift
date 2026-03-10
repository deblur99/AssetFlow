import SwiftUI

struct ShowcaseView: View {
    var body: some View {
        ContentUnavailableView(
            "Showcase",
            systemImage: "iphone.gen3",
            description: Text("Wrap your screenshots in realistic device frames for App Store listings.")
        )
    }
}
