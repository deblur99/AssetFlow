# 프로젝트 개요

## AssetFlow란?

macOS용 **에셋 관리 도구**입니다. 앱 아이콘 디자인, 다국어 문자열 관리, App Store 쇼케이스 제작을 하나의 앱에서 처리하는 것을 목표로 합니다.

- **타겟 플랫폼**: macOS (App Sandbox 활성화)
- **언어**: Swift 6 / SwiftUI + AppKit 하이브리드
- **프로젝트 파일**: `.asflow` (JSON, `IconProject` Codable)
- **번들 ID UTType**: `com.deblurlab.assetflow-project`

## 기술 스택

| 영역 | 선택 |
|------|------|
| UI | SwiftUI (뷰) + AppKit (창·메뉴·다이얼로그) |
| 상태 관리 | `@Observable` (`AppState`, `IconDesignViewModel`) |
| 직렬화 | `Codable` + ISO8601 날짜 |
| 의존성 | 외부 SPM/CocoaPods 없음 (순수 Apple 프레임워크) |
| 빌드 | Xcode 프로젝트 (`AssetFlow.xcodeproj`) |

## 앱 진입 흐름

1. `AssetFlowApp` — SwiftUI `@main`, 커맨드 메뉴만 등록 (실제 창은 AppKit)
2. `AppDelegate` — Welcome 창 표시, SwiftUI placeholder 창 숨김
3. 사용자가 프로젝트를 열면 `NewProjectWindowManager`가 `MainWindowView` 창 생성
4. 모든 프로젝트 창이 닫히면 Welcome 창 복원

## 샌드박스 권한

`AssetFlow.entitlements`:

- App Sandbox
- `files.user-selected.read-write` — 저장/열기 패널 경로
- `files.bookmarks.app-scope` — 최근 프로젝트 security-scoped bookmark

## 키보드 단축키 (주요)

| 단축키 | 동작 |
|--------|------|
| ⌘⇧N | 새 프로젝트 |
| ⌘⇧O | 프로젝트 열기 |
| ⌘⇧S | 프로젝트 저장 |
| ⌘⇧E | 내보내기 |
| ⌘⇧R | 프로젝트 이름 변경 |
| ⌘W | 창 닫기 |
| ⌘+/⌘- | 캔버스 줌 |
