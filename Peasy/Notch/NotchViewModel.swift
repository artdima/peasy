import CoreGraphics
import Observation

@MainActor
@Observable
final class NotchViewModel {
    enum State {
        case collapsed
        case expanded
    }

    var geometry: NotchGeometry?
    var state: State = .collapsed
    var contentSize = CGSize(width: 360, height: 140)

    var isExpanded: Bool { state == .expanded }

    var expandedFrame: CGRect? {
        guard let geometry else { return nil }
        let notch = geometry.notchRect
        let width = max(contentSize.width, notch.width)
        let height = notch.height + contentSize.height
        return CGRect(
            x: notch.midX - width / 2,
            y: geometry.screenFrame.maxY - height,
            width: width,
            height: height
        )
    }

    var hoverZone: CGRect? {
        if isExpanded {
            return expandedFrame
        }
        guard let notch = geometry?.notchRect else { return nil }
        return CGRect(x: notch.minX - 6, y: notch.minY, width: notch.width + 12, height: notch.height + 2)
    }
}
