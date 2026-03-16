import AppKit
import SwiftUI

struct PropertiesPanelView: View {
    @Bindable var vm: IconDesignViewModel
    @State private var panelTab: PanelTab = .attributes

    private enum PanelTab: String, CaseIterable {
        case attributes = "Attributes"
        case export     = "Export"
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Panel tab", selection: $panelTab) {
                ForEach(PanelTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 8)
            .padding(.vertical, 6)

            Divider()

            if panelTab == .attributes {
                VSplitView {
                    ScrollView {
                        VStack(spacing: 0) {
                            if !isBackgroundSelected {
                                transformSection
                                Divider()
                                constraintsSection
                                Divider()
                            }
                            if showsCornerRadius {
                                cornerRadiusSection
                                Divider()
                            }
                            styleSection
                            if hasTextSelection {
                                Divider()
                                typographySection
                            }
                        }
                    }
                    .frame(minHeight: 600)

                    layersSection
                        .frame(minHeight: 60)
                }
            } else {
                ExportPanelView(vm: vm)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .onHover { hover in
            if hover { NSCursor.arrow.set() }
        }
    }

    private var isBackgroundSelected: Bool {
        guard vm.selectedElementIds.count == 1,
              let id = vm.selectedElementIds.first else { return false }
        return vm.backgroundElement?.id == id
    }

    /// Corner Radius 섹션을 표시할 조건: 선택된 사각형 요소 or 사각형 도구 활성 (다중 선택 시 비표시)
    private var showsCornerRadius: Bool {
        if let el = vm.selectedElement, case .shape(let s) = el { return s.shapeType == .rectangle }
        return vm.selectedTool == .rectangle && vm.selectedElementIds.isEmpty
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

    // MARK: - Multi-selection style helpers

    private var selectedElements: [CanvasElement] {
        vm.project.elements.filter { vm.selectedElementIds.contains($0.id) }
    }

    private func colorsEqual(_ a: Color, _ b: Color) -> Bool {
        guard let ca = NSColor(a).usingColorSpace(.sRGB),
              let cb = NSColor(b).usingColorSpace(.sRGB) else { return false }
        return abs(ca.redComponent   - cb.redComponent)   < 0.001 &&
               abs(ca.greenComponent - cb.greenComponent) < 0.001 &&
               abs(ca.blueComponent  - cb.blueComponent)  < 0.001 &&
               abs(ca.alphaComponent - cb.alphaComponent) < 0.001
    }

    /// (표시 값 %, isMixed)
    private var multiOpacity: (CGFloat, Bool) {
        let vals = selectedElements.map { CGFloat($0.opacity) }
        guard let first = vals.first else { return (100, false) }
        let mixed = !vals.dropFirst().allSatisfy { abs($0 - first) < 0.001 }
        return (first * 100, mixed)
    }

    private var multiHasFill: Bool {
        selectedElements.contains { switch $0 { case .shape, .path: return true; default: return false } }
    }

    /// (fillColor, isMixed)
    private var multiFill: (Color, Bool) {
        let colors: [Color] = selectedElements.compactMap {
            switch $0 {
            case .shape(let s): return s.fillColor
            case .path(let p):  return p.color
            default:            return nil
            }
        }
        guard let first = colors.first else { return (.clear, false) }
        return (first, !colors.dropFirst().allSatisfy { colorsEqual($0, first) })
    }

    private var multiAllShapes: Bool {
        !selectedElements.isEmpty &&
        selectedElements.allSatisfy { if case .shape = $0 { return true }; return false }
    }

    /// (strokeColor, isMixed)
    private var multiStrokeColor: (Color, Bool) {
        let colors = selectedElements.compactMap { el -> Color? in
            if case .shape(let s) = el { return s.strokeColor }; return nil
        }
        guard let first = colors.first else { return (.clear, false) }
        return (first, !colors.dropFirst().allSatisfy { colorsEqual($0, first) })
    }

    /// (strokeWidth, isMixed)
    private var multiStrokeWidth: (CGFloat, Bool) {
        let widths = selectedElements.compactMap { el -> CGFloat? in
            if case .shape(let s) = el { return s.strokeWidth }; return nil
        }
        guard let first = widths.first else { return (0, false) }
        return (first, !widths.dropFirst().allSatisfy { abs($0 - first) < 0.01 })
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

    // MARK: - Corner Radius section

    private var cornerRadiusSection: some View {
        GroupBox("Corner Radius") {
            VStack(alignment: .leading, spacing: 8) {
                // ── 전체(uniform) 행 ──────────────────────────────────────
                HStack(spacing: 6) {
                    Image(systemName: "square.on.square")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 14)
                    if let radii = currentCornerRadii {
                        if radii.isUniform {
                            // 모두 같으면 필드 표시
                            TransformFieldView(label: "All", value: radii.topLeft) { v in
                                setCornerRadii(CornerRadii(max(0, v)))
                            }
                        } else {
                            // 값이 다르면 "Mixed" 텍스트 표시
                            Text("All")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 24, alignment: .leading)
                            Text("Mixed")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.tertiary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    } else {
                        // 기본값 모드 (도구 선택 중)
                        TransformFieldView(label: "All", value: vm.cornerRadii.topLeft) { v in
                            vm.cornerRadii = CornerRadii(max(0, v))
                        }
                    }
                }

                // ── 4개 개별 코너 ──────────────────────────────────────
                let radii = currentCornerRadii ?? vm.cornerRadii
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    GridRow {
                        cornerField(label: "↖", value: radii.topLeft) { v in
                            var r = radii; r.topLeft = max(0, v); setCornerRadii(r)
                        }
                        cornerField(label: "↗", value: radii.topRight) { v in
                            var r = radii; r.topRight = max(0, v); setCornerRadii(r)
                        }
                    }
                    GridRow {
                        cornerField(label: "↙", value: radii.bottomLeft) { v in
                            var r = radii; r.bottomLeft = max(0, v); setCornerRadii(r)
                        }
                        cornerField(label: "↘", value: radii.bottomRight) { v in
                            var r = radii; r.bottomRight = max(0, v); setCornerRadii(r)
                        }
                    }
                }
            }
            .padding(2)
        }
        .padding(8)
    }

    /// 선택된 사각형 요소의 CornerRadii, 없으면 nil
    private var currentCornerRadii: CornerRadii? {
        guard let el = vm.selectedElement, case .shape(let s) = el,
              s.shapeType == .rectangle else { return nil }
        return s.cornerRadii
    }

    private func setCornerRadii(_ radii: CornerRadii) {
        if vm.selectedElement != nil {
            vm.updateSelectedStyle(cornerRadii: radii)
        } else {
            vm.cornerRadii = radii
        }
    }

    private func cornerField(label: String, value: CGFloat,
                             onSubmit: @escaping (CGFloat) -> Void) -> some View {
        TransformFieldView(label: label, value: value, onSubmit: onSubmit)
            .frame(maxWidth: .infinity)
    }

    // MARK: - Style section

    private var styleSection: some View {
        GroupBox("Style") {
            VStack(alignment: .leading, spacing: 10) {
                if let el = vm.selectedElement {
                    // ── 단일 요소 선택 ────────────────────────────────────
                    switch el {
                    case .shape(let s):
                        colorRow(label: "Fill",
                                 value: s.fillColor,
                                 onChange: { vm.updateSelectedStyle(fillColor: $0) })
                        strokeRows(
                            isEnabled: s.strokeWidth > 0,
                            currentColor: s.strokeColor,
                            currentWidth: s.strokeWidth,
                            onColorChange: { vm.updateSelectedStyle(strokeColor: $0) },
                            onWidthChange: { vm.updateSelectedStyle(strokeWidth: $0) },
                            onEnable: {
                                let color = IconDesignViewModel.colorIsTransparent(vm.strokeColor)
                                    ? Color.black : vm.strokeColor
                                vm.updateSelectedStyle(strokeColor: color,
                                                       strokeWidth: max(vm.lineWidth, 1))
                            },
                            onDisable: { vm.updateSelectedStyle(strokeWidth: 0) }
                        )
                        sliderRow(label: "Opacity",
                                  value: Binding(get: { CGFloat(s.opacity * 100) },
                                                 set: { vm.updateSelectedStyle(opacity: Double($0 / 100)) }),
                                  range: 0...100, format: "%.0f%%")
                    case .path(let p):
                        colorRow(label: "Stroke",
                                 value: p.color,
                                 onChange: { vm.updateSelectedStyle(strokeColor: $0) })
                        sliderRow(label: "Width",
                                  value: Binding(get: { p.lineWidth },
                                                 set: { vm.updateSelectedStyle(strokeWidth: $0) }),
                                  range: 0.5...40, format: "%.1f")
                        sliderRow(label: "Opacity",
                                  value: Binding(get: { CGFloat(p.opacity * 100) },
                                                 set: { vm.updateSelectedStyle(opacity: Double($0 / 100)) }),
                                  range: 0...100, format: "%.0f%%")
                        penSmoothRow
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
                    case .background(let bg):
                        backgroundStyleContent(bg: bg)
                    }
                } else if !vm.selectedElementIds.isEmpty {
                    // ── 다중 요소 선택 ────────────────────────────────────
                    multiSelectionStyleContent
                } else {
                    // ── 기본값 편집 모드 (새 도형에 적용) ────────────────
                    if vm.selectedTool == .pen {
                        // 펜 도구: Stroke 항상 표시, Fill 없음
                        colorRow(label: "Stroke", value: vm.strokeColor == .clear ? Color.black : vm.strokeColor,
                                 onChange: { vm.strokeColor = $0 })
                        sliderRow(label: "Width",
                                  value: Binding(get: { vm.lineWidth }, set: { vm.lineWidth = $0 }),
                                  range: 0.5...40, format: "%.1f")
                        penSmoothRow
                    } else {
                        colorRow(label: "Fill", value: vm.fillColor, onChange: { vm.fillColor = $0 })
                        let strokeEnabled = !IconDesignViewModel.colorIsTransparent(vm.strokeColor)
                        strokeRows(
                            isEnabled: strokeEnabled,
                            currentColor: vm.strokeColor,
                            currentWidth: vm.lineWidth,
                            onColorChange: { vm.strokeColor = $0 },
                            onWidthChange: { vm.lineWidth = $0 },
                            onEnable: { vm.strokeColor = .black },
                            onDisable: { vm.strokeColor = .clear }
                        )
                        sliderRow(label: "Opacity",
                                  value: Binding(
                                      get: { vm.currentOpacity * 100 },
                                      set: { vm.currentOpacity = $0 / 100 }
                                  ),
                                  range: 0...100, format: "%.0f%%")
                    }
                }
            }
            .padding(2)
        }
        .padding(8)
    }

    /// Stroke 색상 + 너비 행: 비활성(None) / 활성(ColorPicker + Width 슬라이더) 두 상태 관리
    @ViewBuilder
    private func strokeRows(
        isEnabled: Bool,
        currentColor: Color,
        currentWidth: CGFloat,
        onColorChange: @escaping (Color) -> Void,
        onWidthChange: @escaping (CGFloat) -> Void,
        onEnable: @escaping () -> Void,
        onDisable: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 6) {
            Text("Stroke")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)

            if isEnabled {
                ColorPicker("", selection: Binding(get: { currentColor }, set: { onColorChange($0) }),
                            supportsOpacity: true)
                    .labelsHidden()
                Spacer()
                Button { onDisable() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .help("Remove stroke")
            } else {
                Button { onEnable() } label: {
                    HStack(spacing: 5) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .frame(width: 16, height: 16)
                            .overlay(
                                RoundedRectangle(cornerRadius: 3)
                                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                            )
                        Text("None")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                Spacer()
            }
        }

        if isEnabled {
            sliderRow(label: "Width",
                      value: Binding(get: { currentWidth }, set: { onWidthChange($0) }),
                      range: 0.5...40, format: "%.1f")
        }
    }

    private var penSmoothRow: some View {
        HStack {
            Text("Smooth")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            Spacer()
            Toggle("", isOn: $vm.smoothPath)
                .labelsHidden()
                .toggleStyle(.checkbox)
                .help("픽셀을 정리하여 울퉁불퉁한 획을 부드럽게 정돈합니다")
        }
    }

    // MARK: - Background style UI

    @ViewBuilder
    private func backgroundStyleContent(bg: BackgroundElement) -> some View {
        sliderRow(label: "Opacity",
                  value: Binding(get: { CGFloat(bg.opacity * 100) },
                                 set: { vm.updateBackgroundOpacity(Double($0 / 100)) }),
                  range: 0...100, format: "%.0f%%")

        // Solid / Gradient mode toggle
        HStack {
            Text("Fill")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            Picker("", selection: Binding(
                get: { bg.gradient != nil },
                set: { useGradient in
                    vm.updateBackgroundGradient(useGradient ? GradientConfig() : nil)
                }
            )) {
                Text("Solid").tag(false)
                Text("Gradient").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }

        if let grad = bg.gradient {
            gradientRows(config: grad, onChange: { vm.updateBackgroundGradient($0) })
        } else {
            colorRow(label: "Color", value: bg.fillColor,
                     onChange: { vm.updateBackgroundFillColor($0) })
        }
    }

    @ViewBuilder
    private func gradientRows(config: GradientConfig,
                               onChange: @escaping (GradientConfig) -> Void) -> some View {
        // Type picker
        HStack {
            Text("Type")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            Picker("", selection: Binding(
                get: { config.type },
                set: { new in var c = config; c.type = new; onChange(c) }
            )) {
                ForEach(GradientConfig.GradientType.allCases, id: \.self) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }

        // Angle (linear only)
        if config.type == .linear {
            sliderRow(label: "Angle",
                      value: Binding(
                          get: { CGFloat(config.angle) },
                          set: { new in var c = config; c.angle = Double(new); onChange(c) }
                      ),
                      range: 0...360, format: "%.0f°")
        }

        // Color stops
        HStack {
            Text("Stops")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if config.stops.count < 6 {
                Button {
                    var c = config
                    let maxLoc = c.stops.map(\.location).max() ?? 1.0
                    let newLoc = min(maxLoc + 0.15, 1.0)
                    c.stops.append(GradientStop(color: .gray, location: newLoc))
                    c.stops.sort { $0.location < $1.location }
                    onChange(c)
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Add stop")
            }
        }

        ForEach(config.stops.indices, id: \.self) { i in
            HStack(spacing: 6) {
                ColorPicker("", selection: Binding(
                    get: { config.stops[i].color },
                    set: { new in var c = config; c.stops[i].color = new; onChange(c) }
                ), supportsOpacity: true)
                .labelsHidden()
                .frame(width: 28, height: 20)

                Slider(value: Binding(
                    get: { config.stops[i].location },
                    set: { new in var c = config; c.stops[i].location = new; onChange(c) }
                ), in: 0...1)

                Text("\(Int(config.stops[i].location * 100))%")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, alignment: .trailing)

                if config.stops.count > 2 {
                    Button {
                        var c = config
                        c.stops.remove(at: i)
                        onChange(c)
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Remove stop")
                }
            }
        }
    }

    @ViewBuilder
    private var multiSelectionStyleContent: some View {
        let opData = multiOpacity
        mixedSliderRow(
            label: "Opacity",
            value: Binding(get: { opData.0 },
                           set: { vm.updateSelectedStyle(opacity: Double($0 / 100)) }),
            isMixed: opData.1,
            range: 0...100, format: "%.0f%%"
        )

        if multiHasFill {
            let fillData = multiFill
            mixedColorRow(label: "Fill", color: fillData.0, isMixed: fillData.1,
                          onChange: { vm.updateSelectedStyle(fillColor: $0) })
        }

        if multiAllShapes {
            let scData = multiStrokeColor
            mixedColorRow(label: "Stroke", color: scData.0, isMixed: scData.1,
                          onChange: { vm.updateSelectedStyle(strokeColor: $0) })
            let swData = multiStrokeWidth
            mixedSliderRow(
                label: "Width",
                value: Binding(get: { swData.0 },
                               set: { vm.updateSelectedStyle(strokeWidth: $0) }),
                isMixed: swData.1,
                range: 0.5...40, format: "%.1f"
            )
        }
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

    private func mixedColorRow(label: String, color: Color, isMixed: Bool,
                                onChange: @escaping (Color) -> Void) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            ColorPicker("", selection: Binding(
                get: { isMixed ? Color(nsColor: .systemGray) : color },
                set: { onChange($0) }
            ), supportsOpacity: true)
            .labelsHidden()
            if isMixed {
                Text("Mixed")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
    }

    private func mixedSliderRow(
        label: String,
        value: Binding<CGFloat>,
        isMixed: Bool,
        range: ClosedRange<CGFloat>,
        format: String
    ) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            Slider(value: value, in: range)
            Group {
                if isMixed {
                    Text("Mixed").foregroundStyle(.tertiary)
                } else {
                    Text(String(format: format, value.wrappedValue))
                }
            }
            .font(.caption)
            .monospacedDigit()
            .frame(width: 38, alignment: .trailing)
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

    private var typographySection: some View {
        GroupBox("Typography") {
            VStack(alignment: .leading, spacing: 10) {
                // 서체 (시스템 폰트 패널)
                HStack {
                    Text("Font")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .leading)
                    FontPickerButton(
                        fontName: firstSelectedText?.fontName ?? vm.textFontName,
                        fontSize: firstSelectedText?.fontSize ?? vm.textFontSize,
                        isBold:   firstSelectedText?.isBold   ?? vm.textIsBold,
                        isItalic: firstSelectedText?.isItalic ?? vm.textIsItalic,
                        onChange: { vm.updateSelectedTextStyle(fontName: $0) }
                    )
                    .frame(maxWidth: .infinity)
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

                // 스타일 (굵기, 기울기) — ⌘⇧B / ⌘⇧I
                HStack {
                    Text("Style")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 46, alignment: .leading)
                    Toggle(isOn: Binding(
                        get: { firstSelectedText?.isBold ?? vm.textIsBold },
                        set: { vm.updateSelectedTextStyle(isBold: $0) }
                    )) {
                        Image(systemName: "bold").font(.caption)
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .keyboardShortcut("b", modifiers: [.command, .shift])
                    .help("Bold (⌘⇧B)")

                    Toggle(isOn: Binding(
                        get: { firstSelectedText?.isItalic ?? vm.textIsItalic },
                        set: { vm.updateSelectedTextStyle(isItalic: $0) }
                    )) {
                        Image(systemName: "italic").font(.caption)
                    }
                    .toggleStyle(.button)
                    .controlSize(.small)
                    .keyboardShortcut("i", modifiers: [.command, .shift])
                    .help("Italic (⌘⇧I)")
                    Spacer()
                }

                // 색상
                colorRow(
                    label: "Color",
                    value: firstSelectedText?.textColor ?? vm.textColor,
                    onChange: { vm.updateSelectedTextStyle(textColor: $0) }
                )

                // 정렬 — ⌘⇧L / ⌘⇧E / ⌘⇧R
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
                            .keyboardShortcut(alignShortcut(opt), modifiers: [.command, .shift])
                            .help(alignHelp(opt))
                        }
                    }
                }
            }
            .padding(2)
        }
        .padding(8)
    }

    private func alignShortcut(_ opt: TextAlignmentOption) -> KeyEquivalent {
        switch opt {
        case .left:   return "l"
        case .center: return "c"
        case .right:  return "r"
        }
    }

    private func alignHelp(_ opt: TextAlignmentOption) -> String {
        switch opt {
        case .left:   return "Align Left (⌘⇧L)"
        case .center: return "Align Center (⌘⇧C)"
        case .right:  return "Align Right (⌘⇧R)"
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
                let allElementIds = Set(vm.elements.map(\.id))
                let allSelected = !allElementIds.isEmpty && vm.selectedElementIds == allElementIds
                Button {
                    vm.selectedElementIds = allSelected ? [] : allElementIds
                } label: {
                    Image(systemName: allSelected ? "checkmark.square.fill" : "square.on.square")
                        .font(.caption2)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help(allSelected ? "Deselect All" : "Select All")
                Text("\(vm.elements.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            LayersListView(vm: vm)
        }
    }
}

// MARK: - Layers list (Enter-key rename 관리)

private struct LayersListView: View {
    @Bindable var vm: IconDesignViewModel
    @State private var renamingElementId: UUID? = nil

    var body: some View {
        List(vm.elements.reversed(), selection: $vm.selectedElementIds) { element in
            LayerRowView(
                element: element,
                vm: vm,
                renamingElementId: $renamingElementId
            )
            .tag(element.id)
        }
        .listStyle(.plain)
        .onDeleteCommand { vm.deleteSelectedElements() }
        // List가 포커스를 유지하므로 Enter 키를 항상 안정적으로 수신
        .onKeyPress(.return) {
            guard vm.selectedElementIds.count == 1,
                  let id = vm.selectedElementIds.first,
                  renamingElementId == nil,
                  vm.backgroundElement?.id != id else { return .ignored }
            renamingElementId = id
            return .handled
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
                .frame(minWidth: 20, alignment: .leading)
            
            TextField("", text: $text)
                .font(.caption.monospacedDigit())
                .layoutPriority(0.0)
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
    @Binding var renamingElementId: UUID?

    @State private var draftName   = ""
    @FocusState private var fieldFocused: Bool

    private var isRenaming: Bool { renamingElementId == element.id }
    private var isBackground: Bool { if case .background = element { return true }; return false }

    private var isSingleSelected: Bool {
        vm.selectedElementIds.count == 1 && vm.selectedElementIds.contains(element.id)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconName)
                .font(.caption)
                .foregroundStyle(isBackground ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.secondary))
                .frame(width: 14)

            if isRenaming {
                TextField("", text: $draftName)
                    .font(.caption)
                    .lineLimit(1)
                    .textFieldStyle(.plain)
                    .focused($fieldFocused)
                    .onSubmit { commitRename() }
                    .onKeyPress(.escape) { cancelRename(); return .handled }
            } else {
                Text(element.name)
                    .font(.caption)
                    .lineLimit(1)
                    .foregroundStyle(isBackground ? AnyShapeStyle(.primary) : AnyShapeStyle(.primary))
            }

            Spacer()

            Button { vm.toggleVisibility(id: element.id) } label: {
                Image(systemName: element.isVisible ? "eye" : "eye.slash")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(element.isVisible ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
        }
        // 더블 클릭으로 이름 변경 시작 (background 제외)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                guard isSingleSelected, !isBackground else { return }
                startRename()
            }
        )
        .contextMenu {
            if isBackground {
                Text("Background layer").font(.caption).foregroundStyle(.secondary)
            } else {
                let isPartOfMultiSelection = vm.selectedElementIds.count >= 2 && vm.selectedElementIds.contains(element.id)
                if isPartOfMultiSelection {
                    let nonBgSelected = vm.elements.filter { el in
                        guard vm.selectedElementIds.contains(el.id) else { return false }
                        if case .background = el { return false }
                        return true
                    }
                    Button("선택한 레이어 \(nonBgSelected.count)개 내보내기") {
                        ExportService.exportLayers(nonBgSelected, vm: vm)
                    }
                } else {
                    Button("이 레이어 내보내기") {
                        ExportService.exportLayers([element], vm: vm)
                    }
                }
                Divider()
                Button("Rename") { startRename() }
                    .disabled(vm.selectedElementIds.count > 1)
                Divider()
                Button("Bring Forward")  { vm.bringForward(id: element.id) }
                    .keyboardShortcut("]", modifiers: .command)
                Button("Send Backward")  { vm.sendBackward(id: element.id) }
                    .keyboardShortcut("[", modifiers: .command)
                Button("Bring to Front") { vm.bringToFront(id: element.id) }
                    .keyboardShortcut("]", modifiers: [.command, .shift])
                Button("Send to Back")   { vm.sendToBack(id: element.id) }
                    .keyboardShortcut("[", modifiers: [.command, .shift])
                Divider()
                Button("Delete", role: .destructive) { vm.deleteElement(id: element.id) }
                    .keyboardShortcut(.delete, modifiers: [])
            }
        }
        // renamingElementId가 이 행으로 설정되면 TextField 포커스 부여
        .onChange(of: renamingElementId) { _, id in
            if id == element.id {
                draftName = element.name
                Task { @MainActor in fieldFocused = true }
            }
        }
    }

    private func startRename() {
        guard !isBackground else { return }
        draftName = element.name
        renamingElementId = element.id
        Task { @MainActor in fieldFocused = true }
    }

    private func commitRename() {
        vm.renameElement(id: element.id, name: draftName)
        renamingElementId = nil
    }

    private func cancelRename() {
        renamingElementId = nil
    }

    private var iconName: String {
        switch element {
        case .background:        "rectangle.fill"
        case .shape(let s):      s.shapeType == .ellipse ? "circle" : "rectangle"
        case .path:              "scribble"
        case .image:             "photo"
        case .text:              "textformat"
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

// MARK: - Font picker (opens system NSFontPanel)

/// 시스템 폰트 패널을 여는 버튼. ColorPicker처럼 외부 패널에서 서체를 선택한다.
struct FontPickerButton: NSViewRepresentable {
    let fontName: String
    let fontSize: CGFloat
    let isBold: Bool
    let isItalic: Bool
    let onChange: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeNSView(context: Context) -> FontButton {
        let btn = FontButton()
        btn.coordinator = context.coordinator
        return btn
    }

    func updateNSView(_ nsView: FontButton, context: Context) {
        var font = NSFont(name: fontName, size: fontSize) ?? NSFont.systemFont(ofSize: fontSize)
        if isBold   { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)   }
        if isItalic { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
        nsView.currentFont = font
        nsView.title = fontName
        nsView.coordinator = context.coordinator
    }

    // MARK: FontButton

    final class FontButton: NSButton, NSFontChanging {
        var coordinator: Coordinator?
        var currentFont: NSFont = NSFont.systemFont(ofSize: 12)

        init() {
            super.init(frame: .zero)
            bezelStyle = .rounded
            controlSize = .small
            font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
            lineBreakMode = .byTruncatingTail
            target = self
            action = #selector(openPanel)
        }
        required init?(coder: NSCoder) { fatalError() }

        override var acceptsFirstResponder: Bool { true }

        @objc func openPanel() {
            window?.makeFirstResponder(self)
            NSFontManager.shared.setSelectedFont(currentFont, isMultiple: false)
            NSFontPanel.shared.makeKeyAndOrderFront(nil)
        }

        /// NSFontPanel이 서체를 변경하면 NSFontManager가 first responder 체인으로 전달함.
        func changeFont(_ sender: NSFontManager?) {
            guard let sender = sender else { return }
            let newFont = sender.convert(currentFont)
            let family = newFont.familyName ?? newFont.fontName
            coordinator?.onChange(family)
        }
    }

    // MARK: Coordinator

    final class Coordinator: NSObject {
        let onChange: (String) -> Void
        init(onChange: @escaping (String) -> Void) { self.onChange = onChange }
    }
}
