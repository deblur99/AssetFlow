import Foundation

// MARK: - Model

struct RecentProject: Codable, Identifiable {
    let id: UUID
    let name: String
    let urlPath: String
    let lastOpened: Date
    /// Security-Scoped Bookmark — App Sandbox 환경에서 재시작 후에도 파일 접근 권한을 유지하기 위해 사용
    let bookmarkData: Data?

    var url: URL { URL(fileURLWithPath: urlPath) }
    var fileExists: Bool { FileManager.default.fileExists(atPath: urlPath) }

    /// 보안 범위 URL을 해제한다. 사용 후 반드시 stopAccessingSecurityScopedResource() 를 호출해야 한다.
    /// 반환 값이 nil이면 bookmarkData가 없는 것이므로 url 을 직접 사용하면 된다.
    func resolveSecurityScopedURL() -> URL? {
        guard let data = bookmarkData else { return nil }
        var isStale = false
        guard let resolved = try? URL(
            resolvingBookmarkData: data,
            options: .withSecurityScope,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return resolved
    }
}

// MARK: - Service

@MainActor
final class RecentProjectsService {
    static let shared = RecentProjectsService()

    private let key = "com.deblurlab.assetflow.recentProjects"
    private let maxCount = 10

    private(set) var projects: [RecentProject] = []

    private init() { load() }

    func add(name: String, url: URL) {
        // App Sandbox에서 재시작 후에도 접근 가능하도록 security-scoped bookmark를 생성한다
        let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        var updated = projects.filter { $0.urlPath != url.path }
        updated.insert(
            RecentProject(id: UUID(), name: name, urlPath: url.path,
                          lastOpened: Date(), bookmarkData: bookmark),
            at: 0
        )
        projects = Array(updated.prefix(maxCount))
        save()
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([RecentProject].self, from: data)
        else { return }
        projects = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
