import AppKit
import SwiftUI

/// Blurred desktop behind a light surface. A behind-window effect view ignores
/// SwiftUI clipping, so its shape comes from a mask image.
struct GlassBackground: NSViewRepresentable {
    var topRadius: CGFloat = 0
    var bottomRadius: CGFloat

    func makeNSView(context: Context) -> GlassEffectView {
        let view = GlassEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ view: GlassEffectView, context: Context) {
        view.setRadii(top: topRadius, bottom: bottomRadius)
    }
}

final class GlassEffectView: NSVisualEffectView {
    private var topRadius: CGFloat = 0
    private var bottomRadius: CGFloat = 0
    private var maskedSize: CGSize?

    func setRadii(top: CGFloat, bottom: CGFloat) {
        guard top != topRadius || bottom != bottomRadius else { return }
        topRadius = top
        bottomRadius = bottom
        maskedSize = nil
        updateMask()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateMask()
    }

    private func updateMask() {
        let size = bounds.size
        guard size.width > 0, size.height > 0, size != maskedSize else { return }
        maskedSize = size
        maskImage = Self.mask(size: size, top: topRadius, bottom: bottomRadius)
    }

    static func mask(size: CGSize, top: CGFloat, bottom: CGFloat) -> NSImage {
        NSImage(size: size, flipped: false) { rect in
            let top = min(top, rect.width / 2, rect.height / 2)
            let bottom = min(bottom, rect.width / 2, rect.height / 2)
            let w = rect.width
            let h = rect.height
            let path = NSBezierPath()
            path.move(to: NSPoint(x: bottom, y: 0))
            path.line(to: NSPoint(x: w - bottom, y: 0))
            path.appendArc(withCenter: NSPoint(x: w - bottom, y: bottom), radius: bottom, startAngle: 270, endAngle: 360)
            path.line(to: NSPoint(x: w, y: h - top))
            path.appendArc(withCenter: NSPoint(x: w - top, y: h - top), radius: top, startAngle: 0, endAngle: 90)
            path.line(to: NSPoint(x: top, y: h))
            path.appendArc(withCenter: NSPoint(x: top, y: h - top), radius: top, startAngle: 90, endAngle: 180)
            path.line(to: NSPoint(x: 0, y: bottom))
            path.appendArc(withCenter: NSPoint(x: bottom, y: bottom), radius: bottom, startAngle: 180, endAngle: 270)
            path.close()
            NSColor.black.setFill()
            path.fill()
            return true
        }
    }
}

/// The light panel: glass with a hairline highlight around the edge.
struct PanelGlass: View {
    let bottomRadius: CGFloat
    let isVisible: Bool

    var body: some View {
        let shape = UnevenRoundedRectangle(bottomLeadingRadius: bottomRadius, bottomTrailingRadius: bottomRadius, style: .continuous)
        GlassBackground(bottomRadius: bottomRadius)
            .overlay {
                shape.strokeBorder(.white.opacity(0.6), lineWidth: 1)
            }
            .overlay(alignment: .bottom) {
                shape.strokeBorder(.white.opacity(0.9), lineWidth: 1)
                    .mask(alignment: .bottom) {
                        Rectangle().frame(height: bottomRadius)
                    }
            }
            .opacity(isVisible ? 1 : 0)
            .animation(isVisible ? .easeOut(duration: 0.2) : nil, value: isVisible)
            .allowsHitTesting(false)
    }
}
