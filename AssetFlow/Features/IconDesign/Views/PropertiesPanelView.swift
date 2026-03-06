import SwiftUI

struct PropertiesPanelView: View {
    @Bindable var vm: IconDesignViewModel

    var body: some View {
        VSplitView {
            ScrollView {
                VStack(spacing: 0) {
                    transformSection
                    Divider()
                    styleSection
                }
            }
            .frame(minHeight: 160)

            layersSection
                .frame(minHeight: 60)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Transform section

    private var transformSection: some View {
        GroupBox("Transform") {
            VStack(alignment: .leading, spacing: 8) {
                if let el = vm.selectedElement {
                    let f = el.frame
                    HStack(spacing: 8) {
                        transformField(label: "X", value: f.minX) { vm.setElementTransform(id: el.id, x: $0) }
                        transformField(label: "Y", value: f.minY) { vm.setElementTransform(id: el.id, y: $0) }
                    }
                    HStack(spacing: 8) {
                        transformField(label: "W", value: f.width)  { vm.setElementTransform(id: el.id, width: $0) }
                        transformField(label: "H", value: f.height) { vm.setElementTransform(id: el.id, height: $0) }
                    }
                    
                    HStack(spacing: 8) {
                        transformField(label: "°", value: CGFloat(el.rotation)) {
                            vm.setElementTransform(id: el.id, rotation: Double($0))
                        }
                        transformField(label: "H", value: f.height) { vm.setElementTransform(id: el.id, height: $0) }
                            .disabled(true)
                            .opacity(0)
                    }
                } else {
                    Text("No selection")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)
                }
            }
            .padding(2)
        }
        .padding(8)
    }

    private func transformField(label: String,
                                 value: CGFloat,
                                 onSubmit: @escaping (CGFloat) -> Void) -> some View {
        TransformFieldView(label: label, value: value, onSubmit: onSubmit)
    }

    // MARK: - Style section

    private var styleSection: some View {
        GroupBox("Style") {
            VStack(alignment: .leading, spacing: 10) {
                if let el = vm.selectedElement {
                    // ── 선택된 요소 편집 모드 ──────────────────────────────
                    switch el {
                    case .shape(let s):
                        colorRow(label: "Fill",
                                 value: s.fillColor,
                                 onChange: { vm.updateSelectedStyle(fillColor: $0) })
                        colorRow(label: "Stroke",
                                 value: s.strokeColor,
                                 onChange: { vm.updateSelectedStyle(strokeColor: $0) })
                        sliderRow(label: "Width",
                                  value: Binding(get: { s.strokeWidth },
                                                 set: { vm.updateSelectedStyle(strokeWidth: $0) }),
                                  range: 0...40, format: "%.1f")
                        sliderRow(label: "Opacity",
                                  value: Binding(get: { CGFloat(s.opacity * 100) },
                                                 set: { vm.updateSelectedStyle(opacity: Double($0 / 100)) }),
                                  range: 0...100, format: "%.0f%%")
                        sliderRow(label: "Corner",
                                  value: Binding(get: { s.cornerRadius },
                                                 set: { vm.updateSelectedStyle(cornerRadius: $0) }),
                                  range: 0...256, format: "%.0f")
                    case .path(let p):
                        colorRow(label: "Color",
                                 value: p.color,
                                 onChange: { vm.updateSelectedStyle(fillColor: $0) })
                        sliderRow(label: "Width",
                                  value: Binding(get: { p.lineWidth },
                                                 set: { vm.updateSelectedStyle(strokeWidth: $0) }),
                                  range: 0.5...40, format: "%.1f")
                        sliderRow(label: "Opacity",
                                  value: Binding(get: { CGFloat(p.opacity * 100) },
                                                 set: { vm.updateSelectedStyle(opacity: Double($0 / 100)) }),
                                  range: 0...100, format: "%.0f%%")
                    case .image(let i):
                        sliderRow(label: "Opacity",
                                  value: Binding(get: { CGFloat(i.opacity * 100) },
                                                 set: { vm.updateSelectedStyle(opacity: Double($0 / 100)) }),
                                  range: 0...100, format: "%.0f%%")
                    }
                } else {
                    // ── 기본값 편집 모드 (새 도형에 적용) ────────────────
                    colorRow(label: "Fill",   value: vm.fillColor,   onChange: { vm.fillColor   = $0 })
                    colorRow(label: "Stroke", value: vm.strokeColor, onChange: { vm.strokeColor = $0 })
                    sliderRow(label: "Width",
                              value: $vm.lineWidth, range: 0.5...40,
                              format: "%.1f")
                    sliderRow(label: "Opacity",
                              value: Binding(
                                  get: { vm.currentOpacity * 100 },
                                  set: { vm.currentOpacity = $0 / 100 }
                              ),
                              range: 0...100, format: "%.0f%%")
                    if vm.selectedTool == .rectangle {
                        sliderRow(label: "Corner",
                                  value: $vm.cornerRadius, range: 0...256,
                                  format: "%.0f")
                    }
                }
            }
            .padding(2)
        }
        .padding(8)
    }

    private func colorRow(label: String, value: Color, onChange: @escaping (Color) -> Void) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            ColorPicker("", selection: Binding(get: { value }, set: { onChange($0) }),
                        supportsOpacity: true)
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

            List(vm.elements.reversed(), selection: $vm.selectedElementIds) { element in
                LayerRowView(element: element, vm: vm)
                    .tag(element.id)
            }
            .listStyle(.plain)
            .onDeleteCommand {
                vm.deleteSelectedElements()
            }
        }
    }
}

// MARK: - Transform field (label + text input)

private struct TransformFieldView: View {
    let label: String
    let value: CGFloat
    let onSubmit: (CGFloat) -> Void

    @State private var text: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 12, alignment: .leading)
            TextField("", text: $text)
                .font(.caption.monospacedDigit())
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { commitValue() }
                .onAppear { text = formatted(value) }
                .onChange(of: value) { _, v in
                    if !isFocused { text = formatted(v) }
                }
        }
        .frame(maxWidth: .infinity)
    }

    private func commitValue() {
        if let v = Double(text) { onSubmit(CGFloat(v)) }
        else { text = formatted(value) }
    }

    private func formatted(_ v: CGFloat) -> String {
        String(format: "%.1f", v)
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
