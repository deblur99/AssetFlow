import SwiftUI

/// 특정 프로젝트에 종속된 캔버스 편집 상태의 집합.
/// `project.id`를 기준으로 고유하게 식별되며,
/// New Project / Open Project 시 이 단위로 교체된다.
nonisolated struct CanvasState {

    // MARK: - Project data

    var project: IconProject

    // MARK: - Undo / Redo history

    var undoStack: [[CanvasElement]] = []
    var redoStack: [[CanvasElement]] = []

    // MARK: - Selection

    var selectedElementIds: Set<UUID> = []
    var editingTextElementId: UUID?

    // MARK: - Viewport

    var zoom: CGFloat = 1.0
    var canvasOffset: CGSize = .zero

    // MARK: - Clipboard

    var clipboard: CanvasElement?

    // MARK: - Identity

    /// 이 캔버스 상태를 고유하게 식별하는 ID (프로젝트 ID와 동일).
    var id: UUID { project.id }

    // MARK: - Derived

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: - Init

    init(project: IconProject = IconProject()) {
        self.project = project
    }
}
