import Foundation

// MARK: - Model

struct RecentProject: Codable, Identifiable {
    let id: UUID
    let name: String
    let urlPath: String
    let bookmarkData: Data?
    let lastOpened: Date

    var url: URL { URL(fileURLWithPath: urlPath) }
    var fileExists: Bool { FileManager.default.fileExists(atPath: urlPath) }
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
        let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        var updated = projects.filter { $0.urlPath != url.path }
        updated.insert(
            RecentProject(id: UUID(), name: name, urlPath: url.path, bookmarkData: bookmark, lastOpened: Date()),
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
