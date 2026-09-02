import AppKit
import QuartzCore
import SwiftUI

struct BuddyView: NSViewRepresentable {
    var stage: PeaStage
    var scale: CGFloat = 1

    func makeNSView(context: Context) -> BuddyLayerView {
        BuddyLayerView()
    }

    func updateNSView(_ view: BuddyLayerView, context: Context) {
        view.update(stage: stage, scale: scale)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BuddyLayerView, context: Context) -> CGSize? {
        CGSize(width: BuddyLayerView.size.width * scale, height: BuddyLayerView.size.height * scale)
    }
}

final class BuddyLayerView: NSView {
    static let size = CGSize(width: 24, height: 29)
    private static let side: CGFloat = 24

    private static let green = rgb(0x30D158)
    private static let white = rgb(0xF5F5F7)
    private static let petal = rgb(0xFF9EC4)
    private static let bud = rgb(0xFFB3CB)
    private static let yellow = rgb(0xFFD60A)
    private static let stemWidth: CGFloat = 1.3

    private let content = CALayer()
    private let canvas = CALayer()
    private let bodyGroup = BuddyLayerView.group(anchor: CGPoint(x: 12, y: 20.6))
    private let plantLayer = BuddyLayerView.group(anchor: CGPoint(x: 12, y: 8.4))
    private let cheeks = CAShapeLayer()
    private var stage: PeaStage?
    private var scale: CGFloat = 1

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(origin: .zero, size: Self.size))
        wantsLayer = true
        build()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.size.width * scale, height: Self.size.height * scale)
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        content.position = CGPoint(x: bounds.midX, y: bounds.midY)
        content.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        CATransaction.commit()
    }

    func update(stage: PeaStage, scale: CGFloat) {
        if scale != self.scale {
            self.scale = scale
            invalidateIntrinsicContentSize()
            needsLayout = true
        }
        if stage != self.stage {
            let isFirst = self.stage == nil
            self.stage = stage
            showPlant(animated: !isFirst)
        }
    }

    private func build() {
        content.isGeometryFlipped = true
        content.bounds = CGRect(origin: .zero, size: Self.size)
        layer?.addSublayer(content)
        canvas.frame = CGRect(x: 0, y: (Self.size.height - Self.side) / 2, width: Self.side, height: Self.side)
        content.addSublayer(canvas)

        canvas.addSublayer(bodyGroup)
        bodyGroup.addSublayer(plantLayer)

        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: 12, y: 8.4))
        bodyPath.addCurve(to: CGPoint(x: 19.4, y: 15.4), control1: CGPoint(x: 16.3, y: 8.4), control2: CGPoint(x: 19.4, y: 11.5))
        bodyPath.addCurve(to: CGPoint(x: 12, y: 20.6), control1: CGPoint(x: 19.4, y: 18.8), control2: CGPoint(x: 16.6, y: 20.6))
        bodyPath.addCurve(to: CGPoint(x: 4.6, y: 15.4), control1: CGPoint(x: 7.4, y: 20.6), control2: CGPoint(x: 4.6, y: 18.8))
        bodyPath.addCurve(to: CGPoint(x: 12, y: 8.4), control1: CGPoint(x: 4.6, y: 11.5), control2: CGPoint(x: 7.7, y: 8.4))
        bodyPath.closeSubpath()
        let body = Self.shape(fill: Self.white, path: bodyPath)
        bodyGroup.addSublayer(body)

        let cheeksPath = CGMutablePath()
        cheeksPath.addEllipse(in: CGRect(x: 7.7 - 0.95, y: 16.62 - 0.52, width: 1.9, height: 1.04))
        cheeksPath.addEllipse(in: CGRect(x: 16.3 - 0.95, y: 16.62 - 0.52, width: 1.9, height: 1.04))
        cheeks.frame = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        cheeks.path = cheeksPath
        cheeks.fillColor = Self.petal.copy(alpha: 0.75)
        cheeks.isHidden = true
        bodyGroup.addSublayer(cheeks)

        let eyesPath = CGMutablePath()
        eyesPath.addEllipse(in: CGRect(x: 9.5 - 1.05, y: 14.7 - 1.45, width: 2.1, height: 2.9))
        eyesPath.addEllipse(in: CGRect(x: 14.5 - 1.05, y: 14.7 - 1.45, width: 2.1, height: 2.9))
        bodyGroup.addSublayer(Self.shape(fill: NSColor.black.cgColor, path: eyesPath))
    }

    private func showPlant(animated: Bool) {
        guard let stage else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        plantLayer.sublayers = Self.plant(for: stage)
        cheeks.isHidden = stage != .bloom
        CATransaction.commit()

        guard animated, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let pop = CABasicAnimation(keyPath: "transform.scale")
        pop.fromValue = 0.6
        pop.toValue = 1
        pop.duration = 0.6
        pop.timingFunction = CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1)
        plantLayer.add(pop, forKey: "grow")
    }

    private enum Leaf {
        case left
        case right
    }

    private static func plant(for stage: PeaStage) -> [CALayer] {
        switch stage {
        case .pea:
            let hook = CGMutablePath()
            hook.move(to: CGPoint(x: 12, y: 9.2))
            hook.addLine(to: CGPoint(x: 12, y: 7.25))
            hook.addRelativeArc(center: CGPoint(x: 12.6, y: 7.25), radius: 0.6, startAngle: .pi, delta: .pi / 2)
            hook.addLine(to: CGPoint(x: 13, y: 6.65))
            return [shape(stroke: green, width: stemWidth, path: hook)]

        case .hatched:
            return [
                shape(stroke: green, width: stemWidth, path: stem(from: 9.2, to: 6.5)),
                shape(fill: green, path: leaves([(.right, 6.8, 0.64)])),
            ]

        case .sprout:
            let shrink = CGAffineTransform(translationX: 12, y: 8.4).scaledBy(x: 0.66, y: 0.66).translatedBy(x: -12, y: -8.4)
            return [
                shape(stroke: green, width: stemWidth * 0.66, path: stem(from: 9, to: 5.6, transform: shrink)),
                shape(fill: green, path: leaves([(.right, 6, 1), (.left, 6.9, 1)], transform: shrink)),
            ]

        case .grown:
            let curl = CGMutablePath()
            curl.move(to: CGPoint(x: 12, y: 9.2))
            curl.addLine(to: CGPoint(x: 12, y: 4.1))
            curl.addCurve(to: CGPoint(x: 10.45, y: 2.62), control1: CGPoint(x: 12, y: 3.3), control2: CGPoint(x: 11.5, y: 2.62))
            curl.addRelativeArc(center: CGPoint(x: 10.45, y: 2.98), radius: 0.36, startAngle: -.pi / 2, delta: -.pi)
            return [
                shape(fill: green, path: leaves([(.right, 6, 1), (.left, 6.9, 1)])),
                shape(stroke: green, width: stemWidth, path: curl),
            ]

        case .bud, .bloom:
            let tendril = CGMutablePath()
            tendril.move(to: CGPoint(x: 11, y: 1.65))
            tendril.addCurve(to: CGPoint(x: 13.1, y: 1.8), control1: CGPoint(x: 11.6, y: 1.85), control2: CGPoint(x: 12.5, y: 1.85))
            tendril.addCurve(to: CGPoint(x: 14.25, y: 2.95), control1: CGPoint(x: 13.9, y: 1.75), control2: CGPoint(x: 14.3, y: 2.4))
            tendril.addCurve(to: CGPoint(x: 13.8, y: 3.3), control1: CGPoint(x: 14.2, y: 3.45), control2: CGPoint(x: 13.85, y: 3.45))

            var layers = [
                shape(fill: green, path: leaves([(.left, 4.15, 1), (.left, 7.2, 0.9), (.right, 6.25, 0.86)])),
                shape(stroke: green, width: stemWidth, path: stem(from: 9.2, to: 1.5)),
            ]
            if stage == .bud {
                layers.append(shape(fill: bud, path: CGPath(ellipseIn: CGRect(x: 12 - 0.95, y: 0.25 - 1.3, width: 1.9, height: 2.6), transform: nil)))
            }
            layers.append(shape(stroke: green, width: 0.9, path: tendril))
            if stage == .bloom {
                let center = CGPoint(x: 12, y: -0.05)
                let flower = CGMutablePath()
                flower.addEllipse(in: circle(center, radius: 1.3))
                for index in 0..<5 {
                    let angle = -CGFloat.pi / 2 + CGFloat(index) * 2 * .pi / 5
                    flower.addEllipse(in: circle(CGPoint(x: center.x + 1.3 * cos(angle), y: center.y + 1.3 * sin(angle)), radius: 0.95))
                }
                layers.append(shape(fill: petal, path: flower))
                layers.append(shape(fill: yellow, path: CGPath(ellipseIn: circle(center, radius: 0.6), transform: nil)))
            }
            return layers
        }
    }

    private static func stem(from bottom: CGFloat, to top: CGFloat, transform: CGAffineTransform = .identity) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 12, y: bottom), transform: transform)
        path.addLine(to: CGPoint(x: 12, y: top), transform: transform)
        return path
    }

    private static func leaves(_ placements: [(side: Leaf, base: CGFloat, scale: CGFloat)], transform: CGAffineTransform = .identity) -> CGPath {
        let path = CGMutablePath()
        for placement in placements {
            let origin: CGFloat = placement.side == .right ? 6 : 6.9
            let placed = CGAffineTransform(translationX: 12, y: placement.base)
                .scaledBy(x: placement.scale, y: placement.scale)
                .translatedBy(x: -12, y: -origin)
                .concatenating(transform)
            path.addPath(leaf(placement.side), transform: placed)
        }
        return path
    }

    private static func leaf(_ side: Leaf) -> CGPath {
        let path = CGMutablePath()
        switch side {
        case .right:
            path.move(to: CGPoint(x: 12, y: 6))
            path.addCurve(to: CGPoint(x: 16, y: 3.1), control1: CGPoint(x: 12.2, y: 4), control2: CGPoint(x: 13.9, y: 2.9))
            path.addCurve(to: CGPoint(x: 12, y: 6), control1: CGPoint(x: 15.8, y: 5.1), control2: CGPoint(x: 14.1, y: 6.2))
        case .left:
            path.move(to: CGPoint(x: 12, y: 6.9))
            path.addCurve(to: CGPoint(x: 8.9, y: 4.7), control1: CGPoint(x: 11.8, y: 5.4), control2: CGPoint(x: 10.5, y: 4.5))
            path.addCurve(to: CGPoint(x: 12, y: 6.9), control1: CGPoint(x: 9.1, y: 6.2), control2: CGPoint(x: 10.4, y: 7.1))
        }
        path.closeSubpath()
        return path
    }

    private static func circle(_ center: CGPoint, radius: CGFloat) -> CGRect {
        CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    }

    private static func group(anchor: CGPoint) -> CALayer {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        layer.anchorPoint = CGPoint(x: anchor.x / side, y: anchor.y / side)
        layer.position = anchor
        return layer
    }

    private static func shape(fill: CGColor, path: CGPath) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.frame = CGRect(x: 0, y: 0, width: side, height: side)
        layer.path = path
        layer.fillColor = fill
        return layer
    }

    private static func shape(stroke: CGColor, width: CGFloat, path: CGPath) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.frame = CGRect(x: 0, y: 0, width: side, height: side)
        layer.path = path
        layer.fillColor = nil
        layer.strokeColor = stroke
        layer.lineWidth = width
        layer.lineCap = .round
        layer.lineJoin = .round
        return layer
    }

    private static func rgb(_ hex: UInt32) -> CGColor {
        NSColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        ).cgColor
    }
}
