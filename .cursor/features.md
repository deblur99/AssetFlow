# 기능 모듈 현황

## Icon Design — ✅ 주력 기능 (구현됨)

앱 아이콘·그래픽 에셋을 캔버스에서 디자인하고 내보냅니다.

### 구현된 기능

- **캔버스**: 줌, 미니맵, 배경색
- **도구**: 선택, 사각형, 타원, 선, 텍스트, SF Symbol, 이미지
- **레이어**: 순서 변경, 가시성/잠금, 다중 선택, 그룹
- **속성 패널**: 색상, 그라데이션, 그림자, 모서리 반경, 회전, 불투명도
- **프로젝트**: `.asflow` 저장/열기, autosave, PNG→프로젝트 임포트
- **내보내기**: PNG/JPEG/SVG/PDF, 단일 파일 / 레이어 폴더 / 플랫폼별 크기 세트 (iOS, macOS, watchOS, visionOS, Android, Web)
- **Undo/Redo**
- **인라인 텍스트 편집**

### 관련 뷰 구성

```
IconDesignView
├── CanvasToolbarView      (좌측 도구)
├── DesignCanvasView       (중앙 캔버스)
├── PropertiesPanelView    (우측 속성)
├── ExportPanelView        (내보내기)
└── MinimapView            (미니맵)
```

## Welcome — ✅ 구현됨

- 새 프로젝트 / 프로젝트 열기 / PNG 열기
- 최근 프로젝트 목록 (security-scoped bookmark)
- autosave 세션 복원

## String Manager — 🚧 Placeholder

`StringManagerView` — `ContentUnavailableView`만 표시.

> 목표: 다국어 로컬라이즈 문자열을 한곳에서 관리

## Showcase — 🚧 Placeholder

`ShowcaseView` — `ContentUnavailableView`만 표시.

> 목표: App Store용 디바이스 프레임 스크린샷 제작

## Icon Export

`IconExportView` 존재 — Icon Design의 `ExportPanelView` / `ExportService`와 연계된 별도 뷰.
