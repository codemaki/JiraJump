import SwiftUI

// MARK: - 권한 안내 뷰
/// 첫 실행 시 / 권한 없는 상태에서 캡처 시도 시 / 메뉴에서 "권한 설정..." 클릭 시 노출되는 단일 안내.
///
/// 동작:
/// - 표시되어 있는 동안 1초 간격 폴링으로 권한 상태를 갱신해 사용자가 시스템 설정에서 토글하면 즉시 반영.
/// - "권한 요청" 버튼은 첫 결정 전에만 의미가 있음 (그 외엔 시스템 정책상 다이얼로그가 안 뜸).
/// - "시스템 설정 열기" 버튼은 항상 동작.
struct PermissionsView: View {

    let service: PermissionsServicing
    let onDismiss: () -> Void

    @State private var hasPermission: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {

            HStack(spacing: 12) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 32))
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("화면 기록 권한이 필요합니다")
                        .font(.headline)
                    Text("JiraJump")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("선택한 영역을 캡처해 OCR로 Jira 이슈 키를 인식하려면 macOS의 **화면 기록** 권한이 필요합니다.")
                .fixedSize(horizontal: false, vertical: true)

            // 상태 표시
            HStack(spacing: 8) {
                Image(systemName: hasPermission ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(hasPermission ? .green : .orange)
                Text(hasPermission ? "권한 허용됨" : "권한이 허용되지 않음")
                    .fontWeight(.medium)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))

            if !hasPermission {
                Text("**1.** \"시스템 설정 열기\" 버튼을 누르고 \n**2.** 목록에서 JiraJump를 켠 뒤 \n**3.** 앱을 재시작하세요.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            }

            HStack(spacing: 10) {
                Button {
                    service.openSystemSettings()
                } label: {
                    Label("시스템 설정 열기", systemImage: "gear")
                }
                .buttonStyle(.borderedProminent)
                .disabled(hasPermission)

                Button("권한 요청") {
                    _ = service.requestScreenCapturePermission()
                    refresh()
                }
                .disabled(hasPermission)
                .help("첫 실행 시에만 다이얼로그가 뜹니다. 이미 결정된 상태에선 시스템 설정에서 변경해야 합니다.")

                Spacer()

                Button(hasPermission ? "닫기" : "나중에") {
                    onDismiss()
                }
            }
        }
        .padding(24)
        .frame(width: 480)
        .onAppear {
            refresh()
        }
        // 1초마다 폴링: 사용자가 시스템 설정에서 토글하면 라벨이 자동 업데이트.
        .task {
            while !Task.isCancelled {
                refresh()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func refresh() {
        hasPermission = service.hasScreenCapturePermission
    }
}
