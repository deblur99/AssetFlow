# 디렉터리 구조

```
AssetFlow/
├── AssetFlow.xcodeproj/     # Xcode 프로젝트
├── package.json             # 빈 객체 (향후 Node 도구용 placeholder)
├── RESOLVE_CANVAS_PROBLEM.md # 캔버스 버그 트래킹 (루트)
└── AssetFlow/               # 앱 소스
    ├── AssetFlowApp.swift   # @main, Commands (NewProject, File, Zoom)
    ├── AssetFlow.entitlements
    ├── Info.plist           # UTType (.asflow), PNG 연동
    ├── Assets.xcassets/
    │
    ├── App/                 # 앱 수준 조율
    │   ├── AppDelegate.swift          # Welcome 창, 파일 열기, 종료
    │   ├── AppState.swift             # 기능 선택 + IconDesignViewModel 보유
    │   ├── MainWindowView.swift       # NavigationSplitView 셸
    │   └── NewProjectWindowManager.swift  # 다중 창 레지스트리
    │
    ├── Common/              # 공유 UI·유틸
    │   ├── Color+Codable.swift
    │   ├── RenameProjectView.swift
    │   ├── TipBannerView.swift
    │   ├── ToolButton.swift
    │   └── ToolExtraButton.swift
    │
    └── Features/
        ├── Welcome/
        │   ├── WelcomeView.swift           # 시작 화면
        │   └── RecentProjectsService.swift # 최근 프로젝트 + bookmark
        │
        ├── IconDesign/          # ★ 핵심 기능 (가장 큰 모듈)
        │   ├── Models/
        │   │   ├── CanvasElement.swift       # 레이어 타입 정의
        │   │   ├── CanvasElement+Codable.swift
        │   │   ├── CanvasState.swift         # 줌·선택·도구 상태
        │   │   ├── DrawingTool.swift
        │   │   ├── DrawingExtraTool.swift
        │   │   ├── IconProject.swift
        │   │   └── ResizeHandle.swift
        │   ├── ViewModels/
        │   │   └── IconDesignViewModel.swift # 비즈니스 로직 (~1100 lines)
        │   ├── Views/
        │   │   ├── IconDesignView.swift      # 메인 에디터 레이아웃
        │   │   ├── DesignCanvasView.swift    # 캔버스 렌더링·입력
        │   │   ├── CanvasToolbarView.swift
        │   │   ├── PropertiesPanelView.swift
        │   │   ├── ExportPanelView.swift
        │   │   ├── SelectionOverlayView.swift
        │   │   ├── MinimapView.swift
        │   │   ├── SFSymbolPickerView.swift
        │   │   └── InlineTextEditorView.swift
        │   ├── Services/
        │   │   ├── ProjectFileService.swift
        │   │   ├── AutoSaveService.swift
        │   │   └── ExportService.swift
        │   └── Protocols/
        │       └── ToolItem.swift
        │
        ├── IconExport/
        │   └── Views/IconExportView.swift    # (IconDesign ExportPanel과 연계)
        │
        ├── StringManager/
        │   └── Views/StringManagerView.swift # placeholder
        │
        └── Showcase/
            └── Views/ShowcaseView.swift      # placeholder
```

## 모듈 배치 원칙

- **Feature-first**: 기능별 `Models / Views / ViewModels / Services` 분리
- **App/** : 기능에 속하지 않는 앱 전역 조율 코드
- **Common/** : 2개 이상 feature에서 쓰는 공유 컴포넌트
- ViewModel은 `@MainActor @Observable`, Model struct는 `nonisolated` 선호

## 주요 파일 빠른 참조

| 작업 | 파일 |
|------|------|
| 창 생명주기 버그 | `App/AppDelegate.swift`, `App/NewProjectWindowManager.swift` |
| 캔버스 입력/렌더링 | `Features/IconDesign/Views/DesignCanvasView.swift` |
| 레이어 선택·변형 | `Features/IconDesign/Views/SelectionOverlayView.swift` |
| 프로젝트 저장 형식 | `Features/IconDesign/Models/IconProject.swift`, `CanvasElement+Codable.swift` |
| 메뉴 단축키 | `AssetFlowApp.swift` |
