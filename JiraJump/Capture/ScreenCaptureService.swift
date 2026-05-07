import AppKit
import CoreGraphics
import ScreenCaptureKit

// MARK: - 에러
enum ScreenCaptureError: Error {
    /// 캡처할 디스플레이를 찾지 못함.
    case noDisplayFound
    /// ScreenCaptureKit 호출 자체가 실패 (권한 부재 포함).
    case captureFailed(underlying: Error)
}

// MARK: - 프로토콜
/// 화면 캡처 서비스 추상화.
/// Step 6부터는 자체 오버레이 + ScreenCaptureKit 조합으로 구현된다.
protocol ScreenCaptureServicing {
    /// 사용자가 영역을 선택해 캡처한 이미지를 반환한다.
    /// 사용자가 Esc로 취소하면 `nil`.
    func captureInteractive() async throws -> CGImage?
}

// MARK: - 구현 (자체 오버레이 + ScreenCaptureKit)
/// `RegionSelector`로 다중 모니터 영역 선택을 받아내고,
/// `SCScreenshotManager`로 해당 영역만 픽셀 단위 캡처한다.
@MainActor
final class ScreenCaptureKitService: ScreenCaptureServicing {

    private let regionSelector = RegionSelector()

    func captureInteractive() async throws -> CGImage? {

        guard let globalRect = await regionSelector.selectRegion() else {
            return nil
        }

        // 영역이 여러 화면에 걸쳐 있을 때, 중심점이 속한 화면을 캡처 대상으로 선택.
        // (ScreenCaptureKit은 디스플레이 단일 캡처가 기본. v1은 중심점 기준 단순화.)
        let center = CGPoint(x: globalRect.midX, y: globalRect.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) })
            ?? NSScreen.screens.first else {
            throw ScreenCaptureError.noDisplayFound
        }

        // 오버레이 dismiss가 컴포지터에 반영될 시간을 잠깐 줌 (우리 윈도우가 캡처되지 않도록).
        try? await Task.sleep(nanoseconds: 120_000_000)

        return try await capture(globalRect: globalRect, screen: screen)
    }

    // MARK: - SCK 캡처
    private func capture(globalRect: CGRect, screen: NSScreen) async throws -> CGImage {

        // SCDisplay 매칭에 쓰일 CGDirectDisplayID.
        let displayID = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?
            .uint32Value ?? CGMainDisplayID()

        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            // 일반적으로 화면 기록 권한 부재 시 여기서 실패. Step 7에서 권한 안내 추가.
            throw ScreenCaptureError.captureFailed(underlying: error)
        }

        guard let display = content.displays.first(where: { $0.displayID == displayID }) else {
            throw ScreenCaptureError.noDisplayFound
        }

        // 좌표 변환: 글로벌 스크린(좌하단 원점, 포인트) → 디스플레이 로컬(좌상단 원점, 포인트).
        let sx = screen.frame.origin.x
        let sy = screen.frame.origin.y
        let sh = screen.frame.height
        let localX = globalRect.origin.x - sx
        let localTopY = (sy + sh) - (globalRect.origin.y + globalRect.height)
        let sourceRect = CGRect(
            x: localX,
            y: localTopY,
            width: globalRect.width,
            height: globalRect.height
        )

        // 픽셀 단위 출력 크기 = 포인트 × backingScaleFactor (Retina 보정).
        let scale = screen.backingScaleFactor
        let pixelWidth = max(1, Int(globalRect.width * scale))
        let pixelHeight = max(1, Int(globalRect.height * scale))

        let filter = SCContentFilter(display: display, excludingWindows: [])
        let config = SCStreamConfiguration()
        config.width = pixelWidth
        config.height = pixelHeight
        config.sourceRect = sourceRect
        config.scalesToFit = false
        config.showsCursor = false

        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: config
            )
        } catch {
            throw ScreenCaptureError.captureFailed(underlying: error)
        }
    }
}
