import CoreGraphics
import Observation

@MainActor
@Observable
final class NotchViewModel {
    enum State {
        case collapsed
        case expanded
    }

    static let earRadius: CGFloat = 12
    static let collapsedCornerRadius: CGFloat = 10
    static let expandedCornerRadius: CGFloat = 22

    var geometry: NotchGeometry?
    var state: State = .collapsed
    var contentSize = CGSize(width: 360, height: 120)

    var isExpanded: Bool { state == .expanded }

    var collapsedSize: CGSize {
        geometry?.notchRect.size ?? .zero
    }

    var expandedSize: CGSize {
        let notch = collapsedSize
        return CGSize(
            width: max(contentSize.width, notch.width) + 2 * Self.earRadius,
            height: notch.height + contentSize.height
        )
    }

    var expandedFrame: CGRect? {
        guard let geometry else { return nil }
        let size = expandedSize
        return CGRect(
            x: geometry.notchRect.midX - size.width / 2,
            y: geometry.screenFrame.maxY - size.height,
            width: size.width,
            height: size.height
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
