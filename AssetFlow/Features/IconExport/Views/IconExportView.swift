import SwiftUI

struct IconExportView: View {
    var body: some View {
        ContentUnavailableView(
            "Icon Export",
            systemImage: "square.and.arrow.up.on.square",
            description: Text("Export your icon to multiple sizes for iOS and Android projects.")
        )
    }
}
