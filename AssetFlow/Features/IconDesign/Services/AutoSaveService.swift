import Foundation

/// Application Support/AssetFlow/autosave.asflow 에 프로젝트를 자동 저장하는 서비스.
/// 저장·복원 모두 UI 없이 조용히 동작한다.
enum AutoSaveService {

    private static let fileName = "autosave.asflow"

    static var autosaveURL: URL? {
        guard let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        else { return nil }
        let dir = appSupport.appendingPathComponent("AssetFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir,
                                                  withIntermediateDirectories: true)
        return dir.appendingPathComponent(fileName)
    }

    /// 프로젝트를 자동 저장 경로에 기록한다. 실패해도 오류를 전파하지 않는다.
    static func save(project: IconProject) {
        guard let url = autosaveURL else { return }
        guard let data = try? {
            let enc = JSONEncoder()
            enc.dateEncodingStrategy = .iso8601
            return try enc.encode(project)
        }() else { return }
        try? data.write(to: url, options: .atomic)
    }

    /// 자동 저장된 프로젝트를 복원한다. 파일이 없거나 손상되면 nil을 반환한다.
    static func load() -> IconProject? {
        guard let url = autosaveURL,
              FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url)
        else { return nil }
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return try? dec.decode(IconProject.self, from: data)
    }

    /// 자동 저장 파일을 삭제한다 (새 프로젝트 시작 등에 사용).
    static func clear() {
        guard let url = autosaveURL else { return }
        try? FileManager.default.removeItem(at: url)
    }
}
