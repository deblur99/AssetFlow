# 코딩 컨벤션

## Swift / SwiftUI 패턴

### 상태 관리

```swift
@Observable
@MainActor
final class IconDesignViewModel { ... }

@Observable
@MainActor
final class AppState { ... }
```

- ViewModel·AppState는 `@MainActor` + `@Observable`
- View에서 `@Environment(AppState.self)`, `@Bindable` 사용
- Model struct (`IconProject`, `CanvasElement` 등)는 `nonisolated`

### 파일 구조

- `// MARK: - SectionName` 으로 섹션 구분
- Service는 `enum` (인스턴스 불필요) 또는 `@MainActor enum`
- Singleton: `static let shared` (예: `NewProjectWindowManager`, `RecentProjectsService`)

### AppKit + SwiftUI 혼용

- **다이얼로그**: `NSAlert` 직접 사용 (한국어 버튼 레이블)
- **파일 패널**: `NSSavePanel` / `NSOpenPanel` + `async begin()`
- **창**: AppKit `NSWindow` + `NSHostingController`; SwiftUI `WindowGroup`은 placeholder만

### 창 생명주기 주의

```swift
// ✅ 프로젝트 열 때 Welcome 숨김
welcomeWindow?.orderOut(nil)

// ❌ close() 사용 금지 — delegate에서 nil 처리 → 독 메뉴 고스트 창
welcomeWindow?.close()
```

### Codable

- 날짜: ISO8601 (`encoder/decoder.dateEncodingStrategy = .iso8601`)
- `Color` 직렬화: `Common/Color+Codable.swift`
- `CanvasElement` 다형성: `CanvasElement+Codable.swift`

### Concurrency

- UI 작업: `@MainActor`
- `Task { @MainActor in ... }` 로 async 패널 결과 처리
- `nonisolated` enum/struct는 Sendable 경계 넘을 때 사용

## UI 텍스트

- 사용자 대면 문자열: **한국어** (다이얼로그, Welcome 화면)
- 코드 식별자·주석: **영어** 혼용 (기존 코드 스타일 유지)

## 변경 시 원칙

1. **최소 diff** — 요청 범위 밖 리팩터링 금지
2. **기존 패턴 따르기** — 새 추상화보다 인접 코드 스타일 우선
3. **창 관련 변경** — `orderOut` vs `close` 동작 반드시 검증
4. **샌드박스** — 파일 접근은 user-selected 또는 bookmark 경로만

## 테스트

현재 별도 테스트 타겟 없음. 수동 Xcode 빌드·실행으로 검증.
