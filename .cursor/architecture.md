# 아키텍처

## 레이어 구조

```
AssetFlowApp (SwiftUI entry + Commands)
    └── AppDelegate (NSApplicationDelegate — Welcome 창, 파일 열기, 종료 처리)
            └── NewProjectWindowManager (다중 프로젝트 창 레지스트리)
                    └── MainWindowView (NavigationSplitView)
                            └── AppState
                                    └── IconDesignViewModel
                                            └── CanvasState / IconProject
```

## 창 관리 (핵심 설계)

SwiftUI `WindowGroup`은 **커맨드 메뉴 연결용 placeholder**만 사용합니다. 실제 창은 AppKit에서 직접 생성합니다.

### Welcome 창 (`AppDelegate`)

- `welcomeWindow` strong reference로 유지
- 프로젝트 열 때 `orderOut()` (닫지 않음) — `close()` 사용 시 delegate가 nil 처리되어 독 메뉴 고스트 창 발생
- `windowDidBecomeKey`에서 `WelcomeView` rootView 갱신 (최근 프로젝트 목록 refresh)

### 프로젝트 창 (`NewProjectWindowManager`)

- `NSHostingController` + `NSWindowController`로 `MainWindowView` 호스팅
- `entries: [WindowEntry]` — 창별 `AppState` 추적
- 동일 `project.id` 중복 열기 방지 (`focusWindowIfOpen`)
- 마지막 창 닫히면 `AppDelegate.showWelcomeWindow()` 호출

### SwiftUI ↔ AppKit 브릿지

- `@FocusedValue(\.iconDesignVM)` — 메뉴 커맨드가 현재 포커스 창의 ViewModel에 접근
- `NewProjectWindowManager.keyWindowAppState` — 줌 등 전역 커맨드용

## 상태 모델

### AppState

- `selectedFeature: AppFeature` — 사이드바 선택 (iconDesign / stringManager / showcase)
- `iconDesignViewModel: IconDesignViewModel`
- 시작 시 autosave 복원 (`ProjectFileService.loadAutosave()`)

### IconDesignViewModel

- `project: IconProject` — 캔버스 요소·메타데이터
- `canvasState: CanvasState` — 줌, 선택, 도구 상태
- `hasSavedToFile: Bool` — `.asflow` 저장 여부 (autosave 활성화 조건)
- Undo/Redo, 레이어 조작, 내보내기 로직 포함

### IconProject

- `elements: [CanvasElement]` — background, shape, text, image, sfSymbol 등
- Codable JSON → `.asflow` 파일

## 서비스

| 서비스 | 역할 |
|--------|------|
| `ProjectFileService` | 저장/열기 패널, autosave, PNG→프로젝트 임포트 |
| `AutoSaveService` | 타이머 기반 무음 autosave |
| `ExportService` | PNG/JPEG/SVG/PDF, 플랫폼별 아이콘 세트 내보내기 |
| `RecentProjectsService` | 최근 프로젝트 목록 + security-scoped bookmark |

## CanvasElement 타입

`CanvasElement` enum으로 레이어 종류를 표현:

- `background`, `rectangle`, `ellipse`, `line`, `text`, `image`, `sfSymbol`, `group` 등
- 각 요소는 `frame`, `rotation`, `opacity`, `isVisible`, `isLocked` 공통 속성
- `CanvasElement+Codable.swift`에서 직렬화 처리

## 데이터 흐름 (Icon Design)

```
User input (DesignCanvasView)
    → IconDesignViewModel (상태 변경)
    → AutoSaveService (debounced save)
    → ProjectFileService.saveAutosave()
    → ~/Library/Application Support/AssetFlow/autosave.asflow
```

정상 종료 시 autosave 파일 삭제 (`applicationWillTerminate`).
