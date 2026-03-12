import SwiftUI

struct PropertiesPanelView: View {
    @Bindable var vm: IconDesignViewModel

    var body: some View {
        VSplitView {
            ScrollView {
                VStack(spacing: 0) {
                    transformSection
                    Divider()
                    constraintsSection
                    Divider()
                    styleSection
                    if hasTextSelection {
                        Divider()
                        typographySection
                    }
                }
            }
            .frame(minHeight: 500)

            layersSection
                .frame(minHeight: 60)
        }
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Text selection helpers

    private var hasTextSelection: Bool {
        vm.selectedElementIds.contains { id in
            vm.project.elements.first { $0.id == id }.map {
                if case .text = $0 { return true }
                return false
            } ?? false
        }
    }

    private var firstSelectedText: TextElement? {
        for id in vm.selectedElementIds {
            if let el = vm.project.elements.first(where: { $0.id == id }),
               case .text(let t) = el { return t }
        }
        return nil
    }

    // MARK: - Constraints section

    private var constraintsSection: some View {
        GroupBox("Constraints") {
            VStack(alignment: .leading, spacing: 6) {
                if let el = vm.selectedElement {
                    let f = el.frame
                    let cw = vm.project.canvasSize.width
                    let ch = vm.project.canvasSize.height

                    // ── 상단 엣지 ────────────────────────────────────────────
                    HStack {
                        Spacer()
                        constraintField(label: "↑", value: f.minY) { v in
                            vm.setElementFrame(id: el.id, frame: CGRect(
                                x: f.minX, y: v,
                                width: f.width, height: f.height
                            ))
                        }
                        Spacer()
                    }

                    // ── 좌·우 엣지 + 캔버스 미니맵 ──────────────────────────
                    HStack(spacing: 6) {
                        constraintField(label: "←", value: f.minX) { v in
                            vm.setElementFrame(id: el.id, frame: CGRect(
                                x: v, y: f.minY,
                                width: f.width, height: f.height
                            ))
                        }

                        // 캔버스 + 레이어 위치 미니맵
                        ConstraintsMinimap(elementFrame: f, canvasSize: CGSize(width: cw, height: ch))
                            .frame(width: 36, height: 36)

                        constraintField(label: "→", value: cw - f.maxX) { v in
                            vm.setElementFrame(id: el.id, frame: CGRect(
                                x: cw - f.width - v, y: f.minY,
                                width: f.width, height: f.height
                            ))
                        }
                    }

                    // ── 하단 엣지 ────────────────────────────────────────────
                    HStack {
                        Spacer()
                        constraintField(label: "↓", value: ch - f.maxY) { v in
                            vm.setElementFrame(id: el.id, frame: CGRect(
                                x: f.minX, y: ch - f.height - v,
                                width: f.width, height: f.height
                            ))
                        }
                        Spacer()
                    }

                    // ── 중앙 정렬 버튼 ────────────────────────────────────────
                    HStack(spacing: 6) {
                        Button {
                            vm.setElementFrame(id: el.id, frame: CGRect(
                                x: (cw - f.width) / 2, y: f.minY,
                                width: f.width, height: f.height
                            ))
                        } label: {
                            Label("Center X", systemImage: "arrow.left.and.right")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button {
                            vm.setElementFrame(id: el.id, frame: CGRect(
                                x: f.minX, y: (ch - f.height) / 2,
                                width: f.width, height: f.height
                            ))
                        } label: {
                            Label("Center Y", systemImage: "arrow.up.and.down")
                                .font(.caption)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
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

    private func constraintField(label: String,
                                 value: CGFloat,
                                 onSubmit: @escaping (CGFloat) -> Void) -> some View
    {
        TransformFieldView(label: label, value: value, onSubmit: onSubmit)
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
                        transformField(label: "W", value: f.width) { vm.setElementTransform(id: el.id, width: $0) }
                        transformField(label: "H", value: f.height) { vm.setElementTransform(id: el.id, height: $0) }
                    }

                    HStack(spacing: 8) {
                        transformField(label: "°", value: CGFloat(el.rotation)) {
                            vm.setElementTransform(id: el.id, rotation: Double($0))
                        }
                        // Scale % — Path/Text는 배율 기반이므로 Scale 입력 제공
                        ScaleFieldView(element: el) { baseFrame, scale in
                            let newW = baseFrame.width  * scale
                            let newH = baseFrame.height * scale
                            // 크기는 baseFrame 기준, 위치 중심은 현재 위치 유지
                            let cx = el.frame.midX
                            let cy = el.frame.midY
                            vm.setElementFrame(id: el.id, frame: CGRect(
                                x: cx - newW / 2, y: cy - newH / 2,
                                width: newW, height: newH))
                        }
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
                                onSubmit: @escaping (CGFloat) -> Void) -> some View
    {
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
                    case .text(let t):
                        sliderRow(label: "Opacity",
                                  value: Binding(get: { CGFloat(t.opacity * 100) },
                                                 set: { vm.updateSelectedStyle(opacity: Double($0 / 100)) }),
                                  range: 0...100, format: "%.0f%%")
                    }
                } else {
                    // ── 기본값 편집 모드 (새 도형에 적용) ────────────────
                    colorRow(label: "Fill", value: vm.fillColor, onChange: { vm.fillColor = $0 })
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

    // MARK: - Typography section

    // 자주 쓰이는 서체 목록
    private static let availableFonts: [String] = [
        "Helvetica", "Helvetica Neue", "Arial", "Georgia",
        "Times New Roman", "Courier New", "Futura",
        "SF Pro Display", "SF Pro Text"
    ]

    private var typographySection: some View {
        GroupBox("Typography") {
            VStack(alignment: .leading, spacing: 10) {
                // 서체
                HStack {
                    Text("Font")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .leading)
                    Picker("", selection: Binding(
                        get: { firstSelectedText?.fontName ?? vm.textFontName },
                        set: { vm.updateSelectedTextStyle(fontName: $0) }
                    )) {
                        ForEach(Self.availableFonts, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                }

                // 크기
                sliderRow(
                    label: "Size",
                    value: Binding(
                        get: { firstSelectedText?.fontSize ?? vm.textFontSize },
                        set: { vm.updateSelectedTextStyle(fontSize: $0) }
                    ),
                    range: 6...200,
                    format: "%.0f"
                )

                // 스타일 (굵기, 기울기)
                HStack {
                    Text("Style")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .leading)
                    Toggle(isOn: Binding(
                        get: { firstSelectedText?.isBold ?? vm.textIsBold },
                        set: { vm.updateSelectedTextStyle(isBold: $0) }
                    )) {
                        Image(systemName: "bold")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    Toggle(isOn: Binding(
                        get: { firstSelectedText?.isItalic ?? vm.textIsItalic },
                        set: { vm.updateSelectedTextStyle(isItalic: $0) }
                    )) {
                        Image(systemName: "italic")
                            .font(.caption)
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    Spacer()
                }

                // 색상
                colorRow(
                    label: "Color",
                    value: firstSelectedText?.textColor ?? vm.textColor,
                    onChange: { vm.updateSelectedTextStyle(textColor: $0) }
                )

                // 정렬
                HStack {
                    Text("Align")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .leading)
                    HStack(spacing: 4) {
                        ForEach(TextAlignmentOption.allCases, id: \.rawValue) { opt in
                            let isSelected = (firstSelectedText?.alignment ?? vm.textAlignment) == opt

                            Button {
                                vm.updateSelectedTextStyle(alignment: opt)
                            } label: {
                                Image(systemName: opt.sfSymbol)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 12)
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        }
                    }
                }
            }
            .padding(2)
        }
        .padding(8)
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
                .onKeyPress(.upArrow) { step(+1); return .handled }
                .onKeyPress(.downArrow) { step(-1); return .handled }
        }
        .frame(maxWidth: .infinity)
    }

    private func commitValue() {
        if let v = Double(text) { onSubmit(CGFloat(v)) }
        else { text = formatted(value) }
    }

    private func step(_ delta: CGFloat) {
        let current = Double(text) ?? Double(value)
        let next = CGFloat(current) + delta
        text = formatted(next)
        onSubmit(next)
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
            Button("Bring Forward")    { vm.bringForward(id: element.id) }
                .keyboardShortcut("]", modifiers: .command)
            Button("Send Backward")    { vm.sendBackward(id: element.id) }
                .keyboardShortcut("[", modifiers: .command)
            Button("Bring to Front")   { vm.bringToFront(id: element.id) }
                .keyboardShortcut("]", modifiers: [.command, .shift])
            Button("Send to Back")     { vm.sendToBack(id: element.id) }
                .keyboardShortcut("[", modifiers: [.command, .shift])
            Divider()
            Button("Delete", role: .destructive) { vm.deleteElement(id: element.id) }
                .keyboardShortcut(.delete, modifiers: [])
        }
    }

    private var iconName: String {
        switch element {
        case .shape(let s): s.shapeType == .ellipse ? "circle" : "rectangle"
        case .path: "scribble"
        case .image: "photo"
        case .text: "textformat"
        }
    }
}

// MARK: - Constraints minimap

/// 캔버스 내 레이어 위치를 작게 시각화하는 미니맵 뷰
private struct ConstraintsMinimap: View {
    let elementFrame: CGRect
    let canvasSize: CGSize

    var body: some View {
        Canvas { ctx, size in
            // 캔버스 배경
            let canvasRect = CGRect(origin: .zero, size: size)
            ctx.fill(Path(canvasRect), with: .color(Color(nsColor: .controlBackgroundColor)))
            ctx.stroke(Path(roundedRect: canvasRect, cornerRadius: 1.5),
                       with: .color(Color.secondary.opacity(0.4)),
                       lineWidth: 0.5)

            // 레이어 위치 비율 계산 → 미니맵 좌표로 변환
            let scaleX = size.width / canvasSize.width
            let scaleY = size.height / canvasSize.height
            let elRect = CGRect(
                x: elementFrame.minX * scaleX,
                y: elementFrame.minY * scaleY,
                width: max(elementFrame.width * scaleX, 2),
                height: max(elementFrame.height * scaleY, 2)
            )
            ctx.fill(Path(roundedRect: elRect, cornerRadius: 0.5),
                     with: .color(Color.accentColor.opacity(0.7)))
        }
        .clipShape(RoundedRectangle(cornerRadius: 2))
    }
}

// MARK: - Scale field

/// 선택 요소의 크기를 100% 기준으로 표시하고, 입력/방향키로 중심 고정 배율 적용.
/// - 선택 직후 baseFrame을 캡처해 모든 조작은 baseFrame 기준 절대 배율로 적용
/// - 방향키는 즉시 캔버스에 반영
private struct ScaleFieldView: View {
    let element: CanvasElement
    /// (baseFrame, scaleFactor) — caller가 baseFrame 기준으로 element를 리사이즈
    let onScale: (CGRect, CGFloat) -> Void

    @State private var text = "100"
    @State private var baseFrame: CGRect = .zero
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 3) {
            Text("%")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 12, alignment: .leading)
            TextField("", text: $text)
                .font(.caption.monospacedDigit())
                .multilineTextAlignment(.trailing)
                .textFieldStyle(.roundedBorder)
                .focused($isFocused)
                .onSubmit { applyCurrentText() }
                .onAppear   { resetBase() }
                .onChange(of: element.id) { resetBase() }
                .onKeyPress(.upArrow)   { nudge(+1); return .handled }
                .onKeyPress(.downArrow) { nudge(-1); return .handled }
        }
        .frame(maxWidth: .infinity)
    }

    /// 요소가 바뀔 때 현재 frame을 기준(100%)으로 저장
    private func resetBase() {
        baseFrame = element.frame
        text = "100"
    }

    /// 텍스트 필드 엔터 — baseFrame 기준 절대 배율 적용
    private func applyCurrentText() {
        guard let pct = Double(text), pct > 0 else { text = "100"; return }
        onScale(baseFrame, CGFloat(pct) / 100)
    }

    /// 방향키 — 1% 단위 즉시 적용
    private func nudge(_ delta: CGFloat) {
        let current = CGFloat(Double(text) ?? 100)
        let next = max(1, current + delta)
        text = String(format: "%.0f", next)
        onScale(baseFrame, next / 100)
    }
}

#Preview {
    PropertiesPanelView(vm: IconDesignViewModel())
        .frame(width: 240, height: 700)
}
