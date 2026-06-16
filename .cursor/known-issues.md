# 알려진 이슈 및 작업 예정

> 원본: 프로젝트 루트 `RESOLVE_CANVAS_PROBLEM.md`

## 캔버스 — 미해결 (우선순위 높음)

### 1. 그리기 좌표 오프셋

**증상**: 그리기 도구로 그릴 때 포인터 위치보다 오른쪽·아래에 그려짐.

**관련 파일**:
- `Features/IconDesign/Views/DesignCanvasView.swift`
- `Features/IconDesign/ViewModels/IconDesignViewModel.swift`

**추정 원인**: 줌/팬 변환과 마우스 좌표 변환 불일치.

### 2. 그리기 후 도구 자동 전환

**기대 동작**: 도형·선 등 레이어 추가 후 선택 도구로 자동 전환.

**관련 파일**:
- `IconDesignViewModel` — 도구 상태 (`DrawingTool`)
- `CanvasToolbarView`

### 3. 선택 도구 미작동

**증상**:
- 마우스 클릭으로 레이어 선택 불가
- 크기 조절·각도 조절 핸들 미작동

**관련 파일**:
- `DesignCanvasView.swift` — hit testing
- `SelectionOverlayView.swift` — 선택 오버레이·핸들
- `CanvasState.swift` — 선택 상태

## 기타 참고

### Welcome 창 / 독 메뉴 (해결됨)

과거 `close()` 사용 시 고스트 창 누적 문제 → `orderOut()` 패턴으로 수정 (커밋 `2938a7b`, `7d3740e`).

### Placeholder 기능

- String Manager, Showcase — 아직 미구현

## 작업 시 체크리스트

- [ ] 줌 레벨 100% / 200% / 50%에서 그리기·선택 좌표 검증
- [ ] 다중 선택 + 드래그 이동
- [ ] autosave 복원 후 선택·편집 정상 동작
- [ ] 새 창 / 현재 창 프로젝트 열기 시 ViewModel 분리 확인
