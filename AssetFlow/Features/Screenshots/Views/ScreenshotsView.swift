import SwiftUI

struct ScreenshotsView: View {
    var body: some View {
        ContentUnavailableView(
            "Screenshots",
            systemImage: "iphone.gen3",
            description: Text("Wrap your screenshots in realistic device frames for App Store listings.")
        )
    }
}
