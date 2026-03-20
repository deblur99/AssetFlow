import SwiftUI

struct ExportPanelView: View {
    @Bindable var vm: IconDesignViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Export Mode ───────────────────────────────────────────
                sectionHeader("Export Mode")
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                VStack(alignment: .leading, spacing: 4) {
                    ForEach(ExportMode.allCases) { mode in
                        ExportModeRow(
                            mode: mode,
                            isSelected: vm.exportMode == mode,
                            onSelect: { vm.exportMode = mode }
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)

                Divider()

                // ── Mode-specific options ─────────────────────────────────
                switch vm.exportMode {
                case .singleFile:
                    singleFileOptions
                case .layerFolder:
                    layerFolderOptions
                case .platformSizes:
                    platformSizesOptions
                }

                Divider()

                // ── Export without background ─────────────────────────────
                Toggle(isOn: $vm.exportWithoutBackground) {
                    Text("Export without Background Layer")
                        .font(.system(size: 12))
                }
                .toggleStyle(.checkbox)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)

                // ── Export button ─────────────────────────────────────────
                Button {
                    switch vm.exportMode {
                    case .singleFile:
                        ExportService.export(vm: vm)
                    case .layerFolder:
                        ExportService.exportLayerFolder(vm: vm)
                    case .platformSizes:
                        ExportService.exportPlatformSizes(vm: vm)
                    }
                } label: {
                    Label("Export Image", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Single File Options

    private var singleFileOptions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Group {
                sectionHeader("Format")
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                Picker("", selection: $vm.exportFormat) {
                    ForEach(ExportFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }

            Divider()

            Group {
                sectionHeader("Export Size")
                    .padding(.horizontal, 12)
                    .padding(.top, 12)
                    .padding(.bottom, 6)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(ExportSize.allCases) { size in
                        Button {
                            vm.exportSize = size
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: vm.exportSize == size
                                      ? "largecircle.fill.circle"
                                      : "circle")
                                    .foregroundColor(vm.exportSize == size ? .accentColor : .secondary)
                                    .font(.system(size: 14))

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(size.rawValue)
                                        .font(.system(size: 12))
                                        .foregroundColor(.primary)
                                    Text(size.subtitle)
                                        .font(.system(size: 10))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Layer Folder Options

    private var layerFolderOptions: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("각 레이어를 개별 PNG 파일로 내보냅니다.\n파일은 프로젝트 이름의 폴더 안에 저장됩니다.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
        }
    }

    // MARK: - Platform Sizes Options

    private var platformSizesOptions: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeader("Platform")
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 6)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(ExportPlatform.allCases) { platform in
                    let isOn = vm.selectedPlatforms.contains(platform.rawValue)
                    Button {
                        if isOn {
                            vm.selectedPlatforms.remove(platform.rawValue)
                        } else {
                            vm.selectedPlatforms.insert(platform.rawValue)
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: isOn ? "checkmark.square.fill" : "square")
                                .foregroundColor(isOn ? .accentColor : .secondary)
                                .font(.system(size: 14))

                            VStack(alignment: .leading, spacing: 1) {
                                Text(platform.rawValue)
                                    .font(.system(size: 12))
                                    .foregroundColor(.primary)
                                Text("\(platform.sizes.count)개 파일")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
    }
}

// MARK: - Export Mode Row

private struct ExportModeRow: View {
    let mode: ExportMode
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .font(.system(size: 14))

                Text(mode.rawValue)
                    .font(.system(size: 12))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.leading)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
