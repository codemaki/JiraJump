# JiraJump

화면 영역을 캡처해 OCR로 Jira 이슈 키를 추출하고, 해당 이슈 페이지를 브라우저에서 자동으로 여는 macOS 메뉴바 유틸리티.

## 사용법

1. 메뉴바 우상단의 `text.viewfinder` 아이콘 → "캡처 시작" 또는 글로벌 단축키 `⌘⇧J`
2. 화면이 어두워지고 십자 커서 등장 → Jira 키(`PROJ-1234` 등)가 보이는 영역을 드래그
3. 마우스 떼면 OCR이 키를 인식하고 기본 브라우저에서 `{baseURL}{key}` URL을 엽니다
4. `Esc`로 언제든 취소 가능

## 요구사항

- macOS 14 (Sonoma) 이상
- Xcode 15+ (Swift 5.9+)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

## 빌드

```bash
xcodegen generate
xcodebuild -project JiraJump.xcodeproj -scheme JiraJump -configuration Debug build
```

또는 Xcode에서 `JiraJump.xcodeproj` 열고 Run.

`.xcodeproj`는 `project.yml`로부터 자동 생성됩니다. 파일/폴더 추가는 `JiraJump/` 디렉터리에 두면 자동 인식되며, 의존성/빌드 설정은 `project.yml`을 수정 후 `xcodegen generate`.

## 테스트

```bash
xcodebuild -project JiraJump.xcodeproj -scheme JiraJump -destination 'platform=macOS' test
```

`IssueKeyExtractor`(정규식 매칭)와 `URLBuilder`(URL 합성/정규화) 단위 테스트가 포함되어 있습니다.

## 설정

메뉴바 → "설정..." (또는 `⌘,`)

| 항목 | 설명 |
| --- | --- |
| **Base URL** | 이슈 키 직전까지의 전체 URL. 예: `https://your-jira.example.com/browse/`. 끝 슬래시 유무 자동 처리. |
| **글로벌 핫키** | 캡처 트리거 단축키. 기본 `⌘⇧J`. 클릭 후 새 단축키 입력으로 변경. |
| **OCR 인식 언어** | 영어 / 한국어. 둘 다 끄면 영어로 폴백. |
| **캡처 후 동작** | URL 열기 / 클립보드 복사 / 둘 다. |
| **여러 매치 시 선택 UI 표시** | 화면에 키가 여러 개일 때 다이얼로그로 묻기. 끄면 첫 매치 자동 사용. |
| **로그인 시 자동 실행** | `SMAppService.mainApp`로 로그인 항목 등록. |

## 권한

첫 실행 시 **화면 기록** 권한 안내 윈도우가 뜹니다. 시스템 설정 → 개인정보 보호 및 보안 → 화면 기록 → JiraJump 토글 → 앱 재시작.

권한 없는 상태에서 캡처를 시도하면 같은 안내 윈도우가 자동으로 뜹니다. 메뉴바 → "권한 설정..."로도 언제든 열 수 있습니다.

## 아키텍처

```
JiraJump/
├── App/                  # @main, MenuBarExtra, 의존성 그래프 조립
├── Capture/              # 영역 선택 오버레이 + ScreenCaptureKit
├── Coordinator/          # 캡처 → OCR → 키 추출 → URL/복사 플로우
├── Hotkey/               # KeyboardShortcuts 라이브러리 래퍼
├── Jira/                 # 이슈 키 정규식 + URL 빌더
├── Notifications/        # UNUserNotificationCenter 래퍼
├── OCR/                  # Vision VNRecognizeTextRequest 래퍼
├── Permissions/          # Screen Recording 권한 + 안내 윈도우
└── Settings/             # @AppStorage + SwiftUI Form + SMAppService
```

각 서비스는 **프로토콜 + 구현체**로 분리되어 있고, App 진입점에서 의존성 그래프를 한 번 조립해 `CaptureCoordinator`에 주입합니다. 싱글톤은 사용하지 않습니다.

## 알려진 제약

- ad-hoc 서명(`-`) 빌드라 macOS의 권한 캐시(화면 기록, 로그인 항목)가 빌드 변경 시 풀릴 수 있습니다. 정식 배포 시점엔 Developer ID 서명 + 공증이 필요.
- 영역이 두 화면에 걸치면 중심점이 속한 화면만 캡처합니다 (단순화).
- 앱 아이콘은 미포함 (커스텀 `.icns` 추가 필요). About 패널은 시스템 기본.
- 메뉴 항목의 정적 단축키 표기를 일부러 생략 — 사용자가 핫키를 변경했을 때 어긋나지 않도록.

## 의존성

- [KeyboardShortcuts](https://github.com/sindresorhus/KeyboardShortcuts) — 글로벌 핫키 등록 + UserDefaults 영속화 + Recorder UI
- 그 외엔 Apple 표준 프레임워크 (SwiftUI / AppKit / ScreenCaptureKit / Vision / UserNotifications / ServiceManagement)
