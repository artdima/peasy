import AppKit
import SwiftUI

/// Blurred desktop behind a light surface. A behind-window effect view ignores
/// SwiftUI clipping, so its shape comes from a mask image.
struct GlassBackground: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> GlassEffectView {
        let view = GlassEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: GlassEffectView, context: Context) {
        view.cornerRadius = cornerRadius
    }
}

final class GlassEffectView: NSVisualEffectView {
    var cornerRadius: CGFloat = 0 {
        didSet { updateMask() }
    }

    private var maskedRadius: CGFloat?
    private var maskedSize: CGSize?

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateMask()
    }

    /// The mask image is stretched to the view's bounds, so it is redrawn at every size.
    private func updateMask() {
        let size = bounds.size
        guard size.width > 0, size.height > 0, size != maskedSize || cornerRadius != maskedRadius else { return }
        maskedSize = size
        maskedRadius = cornerRadius
        let radius = cornerRadius
        maskImage = NSImage(size: size, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(cgPath: Path(roundedRect: rect, cornerRadius: radius, style: .continuous).cgPath).fill()
            return true
        }
    }
}

/// The light panel: glass with a hairline highlight around the edge.
struct PanelGlass: View {
    let cornerRadius: CGFloat

    private static let edge = Color.white.opacity(0.7)

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        PanelStyle.lightInk
            .overlay {
                GlassBackground(cornerRadius: cornerRadius)
            }
            .overlay {
                shape.strokeBorder(Self.edge, lineWidth: 1)
            }
            .allowsHitTesting(false)
    }
}
