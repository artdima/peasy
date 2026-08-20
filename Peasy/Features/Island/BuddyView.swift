import AppKit
import QuartzCore
import SwiftUI

struct BuddyView: NSViewRepresentable {
    enum Mood: Equatable {
        case focus
        case done
    }

    var mood: Mood
    var growth: CGFloat
    var outlined = false

    func makeNSView(context: Context) -> BuddyLayerView {
        BuddyLayerView()
    }

    func updateNSView(_ view: BuddyLayerView, context: Context) {
        view.update(mood: mood, growth: growth)
        view.setOutlined(outlined)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BuddyLayerView, context: Context) -> CGSize? {
        CGSize(width: BuddyLayerView.side, height: BuddyLayerView.side)
    }
}

final class BuddyLayerView: NSView {
    static let side: CGFloat = 24

    private let content = CALayer()
    private let bodyGroup = BuddyLayerView.group(anchor: CGPoint(x: 12, y: 20.6))
    private let growLayer = BuddyLayerView.group(anchor: CGPoint(x: 12, y: 8.4))
    private let swayLayer = BuddyLayerView.group(anchor: CGPoint(x: 12, y: 8.4))
    private let eyesGroup = BuddyLayerView.group(anchor: CGPoint(x: 12, y: 14.7))
    private let openEyes = CAShapeLayer()
    private let happyEyes = CAShapeLayer()
    private var bodyShape: CAShapeLayer?
    private var sparkles: [CAShapeLayer] = []
    private var mood: BuddyView.Mood?
    private var growth: CGFloat?

    override init(frame frameRect: NSRect) {
        super.init(frame: NSRect(x: 0, y: 0, width: Self.side, height: Self.side))
        wantsLayer = true
        build()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: Self.side, height: Self.side)
    }

    override func layout() {
        super.layout()
        content.frame = bounds
    }

    /// On a light panel the white body needs an edge to stand out.
    func setOutlined(_ outlined: Bool) {
        bodyShape?.strokeColor = outlined ? NSColor.black.withAlphaComponent(0.2).cgColor : nil
        bodyShape?.lineWidth = outlined ? 0.7 : 0
    }

    func update(mood: BuddyView.Mood, growth: CGFloat) {
        if growth != self.growth {
            CATransaction.begin()
            CATransaction.setAnimationDuration(self.growth == nil ? 0 : 0.9)
            CATransaction.setAnimationTimingFunction(CAMediaTimingFunction(controlPoints: 0.34, 1.56, 0.64, 1))
            growLayer.setAffineTransform(CGAffineTransform(scaleX: growth, y: growth))
            CATransaction.commit()
            self.growth = growth
        }
        if mood != self.mood {
            self.mood = mood
            applyAnimations()
        }
    }

    private func build() {
        content.isGeometryFlipped = true
        content.frame = bounds
        layer?.addSublayer(content)

        let green = NSColor(srgbRed: 0x30 / 255, green: 0xD1 / 255, blue: 0x58 / 255, alpha: 1).cgColor
        let white = NSColor(srgbRed: 0xF5 / 255, green: 0xF5 / 255, blue: 0xF7 / 255, alpha: 1).cgColor

        for (radius, color) in [(1.2, green), (1, white), (1, white), (1.2, green)] {
            let sparkle = CAShapeLayer()
            sparkle.frame = CGRect(x: 12 - radius, y: 13 - radius, width: radius * 2, height: radius * 2)
            sparkle.path = CGPath(ellipseIn: CGRect(x: 0, y: 0, width: radius * 2, height: radius * 2), transform: nil)
            sparkle.fillColor = color
            sparkle.opacity = 0
            content.addSublayer(sparkle)
            sparkles.append(sparkle)
        }

        content.addSublayer(bodyGroup)
        bodyGroup.addSublayer(growLayer)
        growLayer.addSublayer(swayLayer)

        let stem = Self.shape(stroke: green, width: 1.3)
        let stemPath = CGMutablePath()
        stemPath.move(to: CGPoint(x: 12, y: 9))
        stemPath.addLine(to: CGPoint(x: 12, y: 5.6))
        stem.path = stemPath
        swayLayer.addSublayer(stem)

        let leaves = Self.shape(fill: green)
        let leavesPath = CGMutablePath()
        leavesPath.move(to: CGPoint(x: 12, y: 6))
        leavesPath.addCurve(to: CGPoint(x: 16, y: 3.1), control1: CGPoint(x: 12.2, y: 4), control2: CGPoint(x: 13.9, y: 2.9))
        leavesPath.addCurve(to: CGPoint(x: 12, y: 6), control1: CGPoint(x: 15.8, y: 5.1), control2: CGPoint(x: 14.1, y: 6.2))
        leavesPath.closeSubpath()
        leavesPath.move(to: CGPoint(x: 12, y: 6.9))
        leavesPath.addCurve(to: CGPoint(x: 8.9, y: 4.7), control1: CGPoint(x: 11.8, y: 5.4), control2: CGPoint(x: 10.5, y: 4.5))
        leavesPath.addCurve(to: CGPoint(x: 12, y: 6.9), control1: CGPoint(x: 9.1, y: 6.2), control2: CGPoint(x: 10.4, y: 7.1))
        leavesPath.closeSubpath()
        leaves.path = leavesPath
        swayLayer.addSublayer(leaves)

        let body = Self.shape(fill: white)
        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: 12, y: 8.4))
        bodyPath.addCurve(to: CGPoint(x: 19.4, y: 15.4), control1: CGPoint(x: 16.3, y: 8.4), control2: CGPoint(x: 19.4, y: 11.5))
        bodyPath.addCurve(to: CGPoint(x: 12, y: 20.6), control1: CGPoint(x: 19.4, y: 18.8), control2: CGPoint(x: 16.6, y: 20.6))
        bodyPath.addCurve(to: CGPoint(x: 4.6, y: 15.4), control1: CGPoint(x: 7.4, y: 20.6), control2: CGPoint(x: 4.6, y: 18.8))
        bodyPath.addCurve(to: CGPoint(x: 12, y: 8.4), control1: CGPoint(x: 4.6, y: 11.5), control2: CGPoint(x: 7.7, y: 8.4))
        bodyPath.closeSubpath()
        body.path = bodyPath
        bodyGroup.addSublayer(body)
        bodyShape = body

        bodyGroup.addSublayer(eyesGroup)
        openEyes.frame = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        openEyes.anchorPoint = CGPoint(x: 0.5, y: 14.7 / Self.side)
        openEyes.position = CGPoint(x: 12, y: 14.7)
        let eyesPath = CGMutablePath()
        eyesPath.addEllipse(in: CGRect(x: 9.5 - 1.05, y: 14.7 - 1.45, width: 2.1, height: 2.9))
        eyesPath.addEllipse(in: CGRect(x: 14.5 - 1.05, y: 14.7 - 1.45, width: 2.1, height: 2.9))
        openEyes.path = eyesPath
        openEyes.fillColor = NSColor.black.cgColor
        eyesGroup.addSublayer(openEyes)

        happyEyes.frame = CGRect(x: 0, y: 0, width: Self.side, height: Self.side)
        let happyPath = CGMutablePath()
        happyPath.move(to: CGPoint(x: 8.4, y: 15.2))
        happyPath.addQuadCurve(to: CGPoint(x: 10.6, y: 15.2), control: CGPoint(x: 9.5, y: 13.7))
        happyPath.move(to: CGPoint(x: 13.4, y: 15.2))
        happyPath.addQuadCurve(to: CGPoint(x: 15.6, y: 15.2), control: CGPoint(x: 14.5, y: 13.7))
        happyEyes.path = happyPath
        happyEyes.fillColor = nil
        happyEyes.strokeColor = NSColor.black.cgColor
        happyEyes.lineWidth = 1.2
        happyEyes.lineCap = .round
        happyEyes.opacity = 0
        eyesGroup.addSublayer(happyEyes)
    }

    private func applyAnimations() {
        for layer in [bodyGroup, swayLayer, eyesGroup, openEyes] + sparkles {
            layer.removeAllAnimations()
        }
        let isDone = mood == .done
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        openEyes.opacity = isDone ? 0 : 1
        happyEyes.opacity = isDone ? 1 : 0
        CATransaction.commit()

        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }

        swayLayer.add(Self.loop("transform.rotation.z", from: -8 * .pi / 180, to: 8 * .pi / 180, duration: 1.6), forKey: "sway")
        if isDone {
            bodyGroup.add(hop(), forKey: "hop")
            let directions = [CGPoint(x: -9, y: -6), CGPoint(x: 9, y: -7), CGPoint(x: -10, y: 3), CGPoint(x: 10, y: 2)]
            for (sparkle, direction) in zip(sparkles, directions) {
                sparkle.add(burst(towards: direction), forKey: "burst")
            }
        } else {
            bodyGroup.add(Self.loop("transform.translation.y", from: 0, to: -1.2, duration: 1.3), forKey: "bob")
            openEyes.add(Self.keyframes("transform.scale.y", values: [1, 1, 0.12, 1], times: [0, 0.93, 0.96, 1], duration: 4.4), forKey: "blink")
            eyesGroup.add(
                Self.keyframes("transform.translation.x", values: [0, 0, 1.3, 1.3, 0, 0], times: [0, 0.55, 0.6, 0.78, 0.83, 1], duration: 7),
                forKey: "glance"
            )
        }
    }

    private func hop() -> CAAnimation {
        let times: [NSNumber] = [0, 0.18, 0.45, 0.7, 0.85, 1]
        let group = CAAnimationGroup()
        group.animations = [
            Self.keyframes("transform.translation.y", values: [0, 0, -5, 0, 0, 0], times: times, duration: 0.8),
            Self.keyframes("transform.scale.x", values: [1, 1.14, 0.92, 1.08, 1, 1], times: times, duration: 0.8),
            Self.keyframes("transform.scale.y", values: [1, 0.84, 1.1, 0.92, 1, 1], times: times, duration: 0.8),
        ]
        group.duration = 0.8
        group.repeatCount = 3
        group.beginTime = CACurrentMediaTime() + 0.35
        group.fillMode = .backwards
        return group
    }

    private func burst(towards direction: CGPoint) -> CAAnimation {
        let opacity = Self.keyframes("opacity", values: [0, 1, 0], times: [0, 0.25, 1], duration: 0.8)
        let moveX = CABasicAnimation(keyPath: "transform.translation.x")
        moveX.fromValue = 0
        moveX.toValue = direction.x
        let moveY = CABasicAnimation(keyPath: "transform.translation.y")
        moveY.fromValue = 0
        moveY.toValue = direction.y
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 0.4
        scale.toValue = 1
        let group = CAAnimationGroup()
        group.animations = [opacity, moveX, moveY, scale]
        group.duration = 0.8
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        group.repeatCount = 3
        group.beginTime = CACurrentMediaTime() + 0.5
        return group
    }

    private static func loop(_ keyPath: String, from: CGFloat, to: CGFloat, duration: CFTimeInterval) -> CAAnimation {
        let animation = CABasicAnimation(keyPath: keyPath)
        animation.fromValue = from
        animation.toValue = to
        animation.duration = duration
        animation.autoreverses = true
        animation.repeatCount = .infinity
        animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        return animation
    }

    private static func keyframes(_ keyPath: String, values: [CGFloat], times: [NSNumber], duration: CFTimeInterval) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.values = values
        animation.keyTimes = times
        animation.duration = duration
        animation.repeatCount = .infinity
        return animation
    }

    private static func group(anchor: CGPoint) -> CALayer {
        let layer = CALayer()
        layer.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        layer.anchorPoint = CGPoint(x: anchor.x / side, y: anchor.y / side)
        layer.position = anchor
        return layer
    }

    private static func shape(fill: CGColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.frame = CGRect(x: 0, y: 0, width: side, height: side)
        layer.fillColor = fill
        return layer
    }

    private static func shape(stroke: CGColor, width: CGFloat) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.frame = CGRect(x: 0, y: 0, width: side, height: side)
        layer.fillColor = nil
        layer.strokeColor = stroke
        layer.lineWidth = width
        layer.lineCap = .round
        return layer
    }
}
