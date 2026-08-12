import SwiftUI

struct Glyph: View {
    enum Kind {
        case pin, plus, chevron, check, checkBold, play, stop, returnKey, refresh, cloud, spinner, gear
        case sliders, sidebar, notchFrame, notchTab, cloudTab
    }

    let kind: Kind
    let size: CGFloat
    var filled = false

    var body: some View {
        let unit = size / kind.viewBox
        ZStack {
            if kind.fillsShape || filled {
                GlyphShape(kind: kind).fill()
            }
            if let width = kind.strokeWidth {
                GlyphShape(kind: kind)
                    .stroke(style: StrokeStyle(lineWidth: width * unit, lineCap: .round, lineJoin: .round))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

extension Glyph.Kind {
    var viewBox: CGFloat {
        switch self {
        case .pin, .gear: 16
        case .chevron: 10
        case .returnKey, .refresh: 14
        case .cloud: 18
        case .sliders, .sidebar, .notchFrame, .notchTab, .cloudTab: 20
        default: 12
        }
    }

    var strokeWidth: CGFloat? {
        switch self {
        case .pin, .gear: 1.4
        case .plus: 1.6
        case .chevron: 1.5
        case .check: 1.8
        case .checkBold: 2.2
        case .play: 1
        case .stop: nil
        case .returnKey: 1.8
        case .refresh, .cloud, .spinner: 1.5
        case .sliders, .sidebar, .notchFrame, .cloudTab: 1.5
        case .notchTab: nil
        }
    }

    var fillsShape: Bool {
        self == .play || self == .stop || self == .notchTab
    }
}

struct GlyphShape: Shape {
    let kind: Glyph.Kind

    func path(in rect: CGRect) -> Path {
        let scale = CGAffineTransform(scaleX: rect.width / kind.viewBox, y: rect.height / kind.viewBox)
        return source.applying(scale.translatedBy(x: rect.minX, y: rect.minY))
    }

    private var source: Path {
        var path = Path()
        switch kind {
        case .pin:
            path.move(to: CGPoint(x: 5.5, y: 1.75))
            path.addLine(to: CGPoint(x: 10.5, y: 1.75))
            path.addLine(to: CGPoint(x: 9.75, y: 6.25))
            path.addLine(to: CGPoint(x: 12.25, y: 8.75))
            path.addLine(to: CGPoint(x: 12.25, y: 10.25))
            path.addLine(to: CGPoint(x: 3.75, y: 10.25))
            path.addLine(to: CGPoint(x: 3.75, y: 8.75))
            path.addLine(to: CGPoint(x: 6.25, y: 6.25))
            path.closeSubpath()
            path.move(to: CGPoint(x: 8, y: 10.25))
            path.addLine(to: CGPoint(x: 8, y: 14.25))
        case .plus:
            path.move(to: CGPoint(x: 6, y: 1.5))
            path.addLine(to: CGPoint(x: 6, y: 10.5))
            path.move(to: CGPoint(x: 1.5, y: 6))
            path.addLine(to: CGPoint(x: 10.5, y: 6))
        case .chevron:
            path.move(to: CGPoint(x: 3.5, y: 2))
            path.addLine(to: CGPoint(x: 6.5, y: 5))
            path.addLine(to: CGPoint(x: 3.5, y: 8))
        case .check, .checkBold:
            path.move(to: CGPoint(x: 2.5, y: 6.2))
            path.addLine(to: CGPoint(x: 4.8, y: 8.5))
            path.addLine(to: CGPoint(x: 9.5, y: 3.8))
        case .play:
            path.move(to: CGPoint(x: 3.8, y: 2.6))
            path.addLine(to: CGPoint(x: 3.8, y: 9.4))
            path.addLine(to: CGPoint(x: 9.4, y: 6))
            path.closeSubpath()
        case .stop:
            path.addRoundedRect(in: CGRect(x: 2.5, y: 2.5, width: 7, height: 7), cornerSize: CGSize(width: 1.5, height: 1.5))
        case .returnKey:
            path.move(to: CGPoint(x: 11.5, y: 3))
            path.addLine(to: CGPoint(x: 11.5, y: 6.8))
            path.addSVGArc(to: CGPoint(x: 9.5, y: 8.8), radius: 2, largeArc: false, sweep: true)
            path.addLine(to: CGPoint(x: 3.2, y: 8.8))
            path.move(to: CGPoint(x: 5.8, y: 6.2))
            path.addLine(to: CGPoint(x: 3.2, y: 8.8))
            path.addLine(to: CGPoint(x: 5.8, y: 11.4))
        case .refresh:
            path.move(to: CGPoint(x: 12, y: 7))
            path.addSVGArc(to: CGPoint(x: 10.54, y: 3.46), radius: 5, largeArc: true, sweep: true)
            path.move(to: CGPoint(x: 10.9, y: 1.2))
            path.addLine(to: CGPoint(x: 10.9, y: 3.6))
            path.addLine(to: CGPoint(x: 8.5, y: 3.6))
        case .cloud:
            path.move(to: CGPoint(x: 5.2, y: 14))
            path.addLine(to: CGPoint(x: 12.8, y: 14))
            path.addSVGArc(to: CGPoint(x: 13.3, y: 7.64), radius: 3.2, largeArc: false, sweep: false)
            path.addSVGArc(to: CGPoint(x: 4.4, y: 8.3), radius: 4.6, largeArc: false, sweep: false)
            path.addSVGArc(to: CGPoint(x: 5.2, y: 14), radius: 2.9, largeArc: false, sweep: false)
            path.closeSubpath()
        case .spinner:
            path.move(to: CGPoint(x: 6, y: 1.2))
            path.addSVGArc(to: CGPoint(x: 1.2, y: 6), radius: 4.8, largeArc: true, sweep: true)
        case .sliders:
            for (from, to) in [(3.0, 11.0), (15.0, 17.0)] {
                path.move(to: CGPoint(x: from, y: 6.5))
                path.addLine(to: CGPoint(x: to, y: 6.5))
            }
            for (from, to) in [(3.0, 5.0), (9.0, 17.0)] {
                path.move(to: CGPoint(x: from, y: 13.5))
                path.addLine(to: CGPoint(x: to, y: 13.5))
            }
            path.addEllipse(in: CGRect(x: 11, y: 4.5, width: 4, height: 4))
            path.addEllipse(in: CGRect(x: 5, y: 11.5, width: 4, height: 4))
        case .sidebar:
            path.addRoundedRect(in: CGRect(x: 2.75, y: 4.25, width: 14.5, height: 11.5), cornerSize: CGSize(width: 2.5, height: 2.5))
            path.move(to: CGPoint(x: 7.75, y: 4.25))
            path.addLine(to: CGPoint(x: 7.75, y: 15.75))
        case .notchFrame:
            path.addRoundedRect(in: CGRect(x: 2.75, y: 3.75, width: 14.5, height: 12.5), cornerSize: CGSize(width: 2.5, height: 2.5))
        case .notchTab:
            path.move(to: CGPoint(x: 7.5, y: 3.75))
            path.addLine(to: CGPoint(x: 12.5, y: 3.75))
            path.addLine(to: CGPoint(x: 12.5, y: 5.25))
            path.addSVGArc(to: CGPoint(x: 11.25, y: 6.5), radius: 1.25, largeArc: false, sweep: true)
            path.addLine(to: CGPoint(x: 8.75, y: 6.5))
            path.addSVGArc(to: CGPoint(x: 7.5, y: 5.25), radius: 1.25, largeArc: false, sweep: true)
            path.closeSubpath()
        case .cloudTab:
            path.move(to: CGPoint(x: 5.8, y: 15.5))
            path.addLine(to: CGPoint(x: 14.2, y: 15.5))
            path.addSVGArc(to: CGPoint(x: 14.75, y: 8.54), radius: 3.5, largeArc: false, sweep: false)
            path.addSVGArc(to: CGPoint(x: 4.9, y: 9.3), radius: 5.1, largeArc: false, sweep: false)
            path.addSVGArc(to: CGPoint(x: 5.8, y: 15.5), radius: 3.2, largeArc: false, sweep: false)
            path.closeSubpath()
        case .gear:
            let center = CGPoint(x: 8, y: 8)
            let teeth = 8
            let outer: CGFloat = 6.9
            let inner: CGFloat = 5.2
            for tooth in 0..<teeth {
                let pitch = .pi * 2 / CGFloat(teeth)
                let start = pitch * CGFloat(tooth) - .pi / 2
                let points = [
                    (start - pitch * 0.17, outer), (start + pitch * 0.17, outer),
                    (start + pitch * 0.3, inner), (start + pitch * 0.7, inner),
                ]
                for (index, (angle, radius)) in points.enumerated() {
                    let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                    if tooth == 0, index == 0 {
                        path.move(to: point)
                    } else {
                        path.addLine(to: point)
                    }
                }
            }
            path.closeSubpath()
            path.addEllipse(in: CGRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4))
        }
        return path
    }
}

extension Path {
    mutating func addSVGArc(to end: CGPoint, radius: CGFloat, largeArc: Bool, sweep: Bool) {
        guard let start = currentPoint else { return }
        let dx = (start.x - end.x) / 2
        let dy = (start.y - end.y) / 2
        var r = radius
        let lambda = (dx * dx + dy * dy) / (r * r)
        if lambda > 1 {
            r *= lambda.squareRoot()
        }
        let numerator = max(r * r * r * r - r * r * (dx * dx + dy * dy), 0)
        let denominator = r * r * (dx * dx + dy * dy)
        var factor = denominator == 0 ? 0 : (numerator / denominator).squareRoot()
        if largeArc == sweep {
            factor = -factor
        }
        let cx1 = factor * r * dy / r
        let cy1 = -factor * r * dx / r
        let center = CGPoint(x: cx1 + (start.x + end.x) / 2, y: cy1 + (start.y + end.y) / 2)
        let startAngle = atan2(start.y - center.y, start.x - center.x)
        let endAngle = atan2(end.y - center.y, end.x - center.x)
        addArc(
            center: center,
            radius: r,
            startAngle: .radians(startAngle),
            endAngle: .radians(endAngle),
            clockwise: !sweep
        )
    }
}
