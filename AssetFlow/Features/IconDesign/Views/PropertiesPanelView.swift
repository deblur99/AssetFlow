import SwiftUI

struct PropertiesPanelView: View {
    @Bindable var vm: IconDesignViewModel

    var body: some View {
        VSplitView {
            ScrollView {
                styleSection
            }
            .frame(minHeight: 120)

            layersSection
                .frame(minHeight: 60)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Style section

    private var styleSection: some View {
        GroupBox("Style") {
            VStack(alignment: .leading, spacing: 10) {
                colorRow(label: "Fill",   color: $vm.fillColor)
                colorRow(label: "Stroke", color: $vm.strokeColor)

                sliderRow(label: "Width",
                          value: $vm.lineWidth, range: 0.5...40,
                          format: "%.1f")

                sliderRow(label: "Opacity",
                          value: Binding(
                              get: { vm.currentOpacity * 100 },
                              set: { vm.currentOpacity = $0 / 100 }
                          ),
                          range: 0...100,
                          format: "%.0f%%")

                if vm.selectedTool == .rectangle {
                    sliderRow(label: "Corner",
                              value: $vm.cornerRadius, range: 0...256,
                              format: "%.0f")
                }
            }
            .padding(2)
        }
        .padding(8)
    }

    private func colorRow(label: String, color: Binding<Color>) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            ColorPicker("", selection: color, supportsOpacity: true)
                .labelsHidden()
        }
    }

    private func sliderRow(
        label: String,
        value: Binding<CGFloat>,
        range: ClosedRange<CGFloat>,
        format: String
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue))
                .font(.caption)
                .monospacedDigit()
                .frame(width: 38, alignment: .trailing)
        }
    }

    // MARK: - Layers section

    private var layersSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Layers")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(vm.elements.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            List(vm.elements.reversed(), selection: $vm.selectedElementId) { element in
                LayerRowView(element: element, vm: vm)
                    .tag(element.id)
            }
            .listStyle(.plain)
        }
    }
}

// MARK: - Layer row

private struct LayerRowView: View {
    let element: CanvasElement
    @Bindable var vm: IconDesignViewModel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            Text(element.name)
                .font(.caption)
                .lineLimit(1)

            Spacer()

            Button { vm.toggleVisibility(id: element.id) } label: {
                Image(systemName: element.isVisible ? "eye" : "eye.slash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(element.isVisible ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
        }
        .contextMenu {
            Button("Bring Forward") { vm.bringForward(id: element.id) }
            Button("Send Backward") { vm.sendBackward(id: element.id) }
            Divider()
            Button("Delete", role: .destructive) { vm.deleteElement(id: element.id) }
        }
    }

    private var iconName: String {
        switch element {
        case .shape(let s): s.shapeType == .ellipse ? "circle" : "rectangle"
        case .path:         "scribble"
        case .image:        "photo"
        }
    }
}
