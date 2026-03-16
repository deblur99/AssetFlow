import SwiftUI

// MARK: - SF Symbol Picker Sheet

struct SFSymbolPickerView: View {
    @Bindable var vm: IconDesignViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""
    @State private var hoveredSymbol: String? = nil

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)

    var body: some View {
        VStack(spacing: 0) {
            // ── Header ────────────────────────────────────────────────────
            HStack {
                Text("SF Symbols")
                    .font(.headline)
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 10)

            // ── Search field ──────────────────────────────────────────────
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search symbols…", text: $searchText)
                    .textFieldStyle(.plain)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // ── Symbol grid ───────────────────────────────────────────────
            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(filteredSymbols, id: \.self) { name in
                        SymbolCell(
                            name: name,
                            isHovered: hoveredSymbol == name
                        ) {
                            vm.addSymbol(name: name)
                            dismiss()
                        }
                        .onHover { isHovered in
                            hoveredSymbol = isHovered ? name : nil
                        }
                    }
                }
                .padding(12)
            }
        }
        .frame(width: 420, height: 500)
    }

    private var filteredSymbols: [String] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return SFSymbolList.all }
        return SFSymbolList.all.filter { $0.localizedCaseInsensitiveContains(query) }
    }
}

// MARK: - Individual symbol cell

private struct SymbolCell: View {
    let name: String
    let isHovered: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: name)
                    .font(.system(size: 22))
                    .frame(width: 32, height: 32)
                Text(name)
                    .font(.system(size: 7))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
            .background(isHovered ? Color.accentColor.opacity(0.15) : .clear,
                        in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SF Symbol name list

enum SFSymbolList {
    static let all: [String] = [
        // Communication
        "message", "message.fill", "envelope", "envelope.fill", "phone", "phone.fill",
        "video", "video.fill", "mic", "mic.fill", "speaker", "speaker.fill",
        "speaker.wave.2", "speaker.wave.2.fill", "speaker.slash", "bell", "bell.fill",
        "bell.slash", "megaphone", "megaphone.fill", "antenna.radiowaves.left.and.right",
        "bubble.left", "bubble.left.fill", "bubble.right", "bubble.right.fill",
        "quote.bubble", "text.bubble", "exclamationmark.bubble",

        // Devices
        "desktopcomputer", "laptopcomputer", "iphone", "ipad", "applewatch",
        "airpods", "headphones", "keyboard", "mouse", "printer", "scanner",
        "tv", "gamecontroller", "gamecontroller.fill",

        // Media
        "play", "play.fill", "pause", "pause.fill", "stop", "stop.fill",
        "backward", "forward", "backward.fill", "forward.fill",
        "shuffle", "repeat", "music.note", "music.note.list", "music.mic",
        "waveform", "waveform.circle", "film", "camera", "camera.fill",
        "camera.aperture", "photo", "photo.fill", "photo.on.rectangle",
        "photo.stack", "video.circle", "play.circle", "play.circle.fill",
        "play.rectangle", "play.rectangle.fill",

        // Navigation & Maps
        "map", "map.fill", "location", "location.fill", "location.circle",
        "compass.drawing", "arrow.up.left.and.arrow.down.right",
        "magnifyingglass", "magnifyingglass.circle", "globe",
        "globe.americas", "globe.europe.africa", "globe.asia.australia",

        // People & Faces
        "person", "person.fill", "person.circle", "person.circle.fill",
        "person.2", "person.2.fill", "person.3", "person.3.fill",
        "person.crop.circle", "person.crop.square", "figure.walk",
        "figure.run", "figure.stand", "face.smiling", "face.dashed",

        // System
        "house", "house.fill", "gearshape", "gearshape.fill",
        "gearshape.2", "wrench", "wrench.fill", "hammer", "hammer.fill",
        "screwdriver", "screwdriver.fill", "lock", "lock.fill", "lock.open",
        "lock.open.fill", "key", "key.fill", "shield", "shield.fill",
        "checkmark.shield", "xmark.shield", "exclamationmark.shield",

        // Files & Folders
        "folder", "folder.fill", "doc", "doc.fill", "doc.text", "doc.text.fill",
        "doc.richtext", "doc.richtext.fill", "doc.on.clipboard",
        "clipboard", "clipboard.fill", "paperclip", "link",
        "archivebox", "archivebox.fill", "tray", "tray.fill",
        "tray.2", "tray.2.fill", "externaldrive", "externaldrive.fill",

        // Arrows
        "arrow.left", "arrow.right", "arrow.up", "arrow.down",
        "arrow.left.right", "arrow.up.down",
        "arrow.turn.up.left", "arrow.turn.up.right",
        "arrow.clockwise", "arrow.counterclockwise",
        "arrow.triangle.2.circlepath", "arrow.uturn.left", "arrow.uturn.right",
        "chevron.left", "chevron.right", "chevron.up", "chevron.down",
        "chevron.left.forwardslash.chevron.right",

        // Shapes & Objects
        "star", "star.fill", "star.leadinghalf.filled",
        "heart", "heart.fill", "heart.circle", "heart.circle.fill",
        "bookmark", "bookmark.fill", "flag", "flag.fill",
        "tag", "tag.fill", "seal", "seal.fill",
        "checkmark.seal", "xmark.seal", "rosette",
        "sparkles", "sparkle", "bolt", "bolt.fill", "bolt.circle",
        "flame", "flame.fill", "drop", "drop.fill",
        "leaf", "leaf.fill", "snowflake", "wind",
        "cloud", "cloud.fill", "sun.max", "sun.max.fill",
        "moon", "moon.fill", "moon.stars", "moon.stars.fill",
        "rainbow", "tornado",

        // Text & Writing
        "pencil", "pencil.circle", "pencil.circle.fill",
        "highlighter", "paintbrush", "paintbrush.fill",
        "paintpalette", "paintpalette.fill",
        "eraser", "eraser.fill",
        "text.cursor", "text.alignleft", "text.aligncenter",
        "text.alignright", "text.justify", "textformat",
        "textformat.abc", "textformat.size", "bold", "italic", "underline",
        "strikethrough", "character", "abc",

        // Math & Science
        "function", "sum", "plusminus", "plus", "minus",
        "multiply", "divide", "equal", "lessthan", "greaterthan",
        "infinity", "percent", "number",

        // UI Controls
        "slider.horizontal.3", "slider.vertical.3",
        "switch.2", "toggle.on", "toggle.off",
        "circle", "circle.fill", "circle.dashed",
        "square", "square.fill", "square.dashed",
        "rectangle", "rectangle.fill",
        "triangle", "triangle.fill",
        "diamond", "diamond.fill",
        "hexagon", "hexagon.fill",
        "pentagon", "pentagon.fill",
        "oval", "oval.fill",
        "capsule", "capsule.fill",

        // Editing
        "scissors", "scissors.circle",
        "crop", "crop.rotate",
        "wand.and.rays", "wand.and.stars",
        "ruler", "ruler.fill",
        "skew", "perspective",
        "cube", "cube.fill", "cylinder", "sphere",
        "move.3d", "scale.3d",

        // Network & Connectivity
        "wifi", "wifi.slash", "wifi.circle",
        "bluetooth", "dot.radiowaves.left.and.right",
        "network", "server.rack",
        "icloud", "icloud.fill", "icloud.and.arrow.up", "icloud.and.arrow.down",
        "shareplay", "shared.with.you",

        // Time
        "clock", "clock.fill", "alarm", "alarm.fill",
        "stopwatch", "stopwatch.fill",
        "timer", "timer.circle",
        "calendar", "calendar.circle",

        // Finance
        "creditcard", "creditcard.fill",
        "banknote", "banknote.fill",
        "cart", "cart.fill",
        "bag", "bag.fill",
        "gift", "gift.fill",
        "dollarsign.circle", "dollarsign.circle.fill",
        "eurosign.circle", "sterlingsign.circle",

        // Health & Fitness
        "heart.text.square", "cross", "cross.fill",
        "cross.circle", "staroflife", "staroflife.fill",
        "figure.walk.circle", "figure.run.circle",

        // Misc
        "info.circle", "info.circle.fill",
        "questionmark.circle", "questionmark.circle.fill",
        "exclamationmark.circle", "exclamationmark.circle.fill",
        "checkmark.circle", "checkmark.circle.fill",
        "xmark.circle", "xmark.circle.fill",
        "minus.circle", "minus.circle.fill",
        "plus.circle", "plus.circle.fill",
        "multiply.circle", "multiply.circle.fill",
        "trash", "trash.fill", "trash.circle",
        "eye", "eye.fill", "eye.slash",
        "hand.raised", "hand.raised.fill",
        "hand.thumbsup", "hand.thumbsup.fill",
        "hand.thumbsdown", "hand.thumbsdown.fill",
        "hands.clap", "hands.sparkles",
        "lightbulb", "lightbulb.fill",
        "poweroff", "power",
        "app", "app.fill", "apps.iphone", "apps.ipad",
        "square.grid.2x2", "square.grid.3x3", "rectangle.grid.2x2",
        "list.bullet", "list.number", "list.dash",
        "chart.bar", "chart.bar.fill", "chart.pie", "chart.pie.fill",
        "chart.line.uptrend.xyaxis",
        "scope", "target", "dot.scope",
        "qrcode", "barcode",
        "airplane", "car", "car.fill", "bus", "tram", "bicycle",
        "ferry", "sailboat", "fuelpump", "fuelpump.fill",
        "house.and.flag", "building.2", "building.columns",
        "bed.double", "sofa", "lamp.desk",
        "fork.knife", "cup.and.saucer", "wineglass",
        "takeoutbag.and.cup.and.straw",
    ]
}
