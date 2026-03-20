import SwiftUI
import AppKit

struct WelcomeView: View {
    @State private var recentProjects: [RecentProject] = []
    @State private var autosaveProject: IconProject? = nil

    var body: some View {
        HStack(spacing: 0) {
            leftPanel
            if !recentProjects.isEmpty || autosaveProject != nil {
                Divider()
                rightPanel
            }
        }
        .frame(
            width: (recentProjects.isEmpty && autosaveProject == nil) ? 360 : 660,
            height: 460
        )
        .onAppear {
            recentProjects = RecentProjectsService.shared.projects.filter { $0.fileExists }
            autosaveProject = ProjectFileService.loadAutosave()
        }
    }

    // MARK: - Left panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            // App icon + name
            VStack(alignment: .leading, spacing: 6) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 72, height: 72)
                Text("AssetFlow")
                    .font(.system(size: 26, weight: .semibold))
                Text("A Simple Asset Managing Tool")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 36)
            .padding(.horizontal, 28)

            Spacer()

            // Action buttons
            VStack(alignment: .leading, spacing: 8) {
                if let autosave = autosaveProject {
                    WelcomeActionButton(
                        icon: "clock.arrow.circlepath",
                        title: "마지막 세션 이어서 열기",
                        subtitle: autosave.name
                    ) {
                        openAndCloseWelcome {
                            NewProjectWindowManager.shared.open(with: autosave, fromFile: true)
                        }
                    }
                    Divider().padding(.vertical, 4)
                }

                WelcomeActionButton(icon: "plus.square", title: "새 프로젝트") {
                    openAndCloseWelcome { NewProjectWindowManager.shared.open() }
                }

                WelcomeActionButton(icon: "folder", title: "프로젝트 열기…") {
                    Task {
                        guard let project = await ProjectFileService.openProject() else { return }
                        if NewProjectWindowManager.shared.focusWindowIfOpen(projectID: project.id) {
                            (NSApp.delegate as? AppDelegate)?.closeWelcomeIfProjectOpen()
                            return
                        }
                        openAndCloseWelcome {
                            NewProjectWindowManager.shared.open(with: project, fromFile: true)
                        }
                    }
                }

                WelcomeActionButton(icon: "photo", title: "PNG를 프로젝트로 열기…") {
                    Task {
                        guard let project = await ProjectFileService.openPNGAsProject() else { return }
                        openAndCloseWelcome {
                            NewProjectWindowManager.shared.open(with: project)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .frame(width: 360)
        .background(.background)
    }

    // MARK: - Right panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("최근 프로젝트")
                .font(.headline)
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 10)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(recentProjects) { project in
                        RecentProjectRow(project: project) {
                            openRecentProject(project)
                        }
                        Divider().padding(.leading, 16)
                    }
                }
            }
        }
        .frame(width: 300)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Actions

    private func openRecentProject(_ recent: RecentProject) {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // App Sandbox: bookmark가 있으면 security-scoped URL로 접근한다
        let scopedURL = recent.resolveSecurityScopedURL()
        let accessURL = scopedURL ?? recent.url
        let didStart = scopedURL != nil && accessURL.startAccessingSecurityScopedResource()

        defer {
            if didStart { accessURL.stopAccessingSecurityScopedResource() }
        }

        guard let data = try? Data(contentsOf: accessURL),
              let project = try? decoder.decode(IconProject.self, from: data)
        else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "파일을 열 수 없습니다"
            alert.informativeText = recent.urlPath
            alert.addButton(withTitle: "확인")
            alert.runModal()
            recentProjects.removeAll { $0.id == recent.id }
            return
        }

        if NewProjectWindowManager.shared.focusWindowIfOpen(projectID: project.id) {
            (NSApp.delegate as? AppDelegate)?.closeWelcomeIfProjectOpen()
            return
        }
        openAndCloseWelcome {
            NewProjectWindowManager.shared.open(with: project, fromFile: true)
            RecentProjectsService.shared.add(name: project.name, url: accessURL)
        }
    }

    private func openAndCloseWelcome(_ action: @MainActor () -> Void) {
        let welcome = NSApp.keyWindow
        action()
        welcome?.close()
    }
}

// MARK: - WelcomeActionButton

private struct WelcomeActionButton: View {
    let icon: String
    let title: String
    var subtitle: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 28)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.001)) // hit area
        .hoverEffect()
    }
}

// MARK: - RecentProjectRow

private struct RecentProjectRow: View {
    let project: RecentProject
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.blue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.name)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    Text(project.url.deletingLastPathComponent().path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(project.lastOpened.formatted(.relative(presentation: .named)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.15) : .clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Hover effect helper

private extension View {
    @ViewBuilder
    func hoverEffect() -> some View {
        modifier(HoverHighlightModifier())
    }
}

private struct HoverHighlightModifier: ViewModifier {
    @State private var isHovered = false
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered
                          ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.15)
                          : .clear)
            )
            .onHover { isHovered = $0 }
    }
}
