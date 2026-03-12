import SwiftUI

struct ExportPanelView: View {
    @Bindable var vm: IconDesignViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Format
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

                // Size
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

                Divider()

                // Export button
                Button {
                    ExportService.export(vm: vm)
                } label: {
                    Label("Export Image", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(12)
            }
        }
    }

    @ViewBuilder
    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
    }
}
