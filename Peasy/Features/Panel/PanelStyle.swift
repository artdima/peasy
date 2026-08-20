import AppKit
import SwiftUI

/// Colors of the panel and the windows around it. Each one resolves against the
/// appearance it is drawn in, so the theme is chosen by setting a window's appearance.
enum PanelStyle {
    static let primary = Color.themed(dark: "#F5F5F7", light: "#1D1D1F")
    static let secondary = Color.themed(dark: "#98989F", light: "#6E6E73")
    static let tertiary = Color.themed(dark: "#8E8E93", light: "#6E6E73")
    static let separator = Color.themed(white: 0.08, black: 0.08)
    static let hover = Color.themed(white: 0.06, black: 0.045)
    static let strongHover = Color.themed(white: 0.1, black: 0.07)
    static let selection = Color.themed(white: 0.12, black: 0.075)
    static let pillSelection = Color.themed(white: 0.13, black: 0.075)
    static let keyBorder = Color.themed(white: 0.18, black: 0.16)
    static let green = Color(hex: "#30D158")

    /// The collapsed notch and its cloud stay black in every theme.
    static let onBlack = Color(hex: "#F5F5F7")
    static let lightInk = Color(red: 0.965, green: 0.965, blue: 0.975)
}

extension Color {
    init(hex: String) {
        self.init(nsColor: NSColor(hex: hex))
    }

    static func themed(dark: String, light: String) -> Color {
        themed(dark: NSColor(hex: dark), light: NSColor(hex: light))
    }

    /// A white overlay in dark mode, a black one in light mode.
    static func themed(white: CGFloat, black: CGFloat) -> Color {
        themed(dark: NSColor.white.withAlphaComponent(white), light: NSColor.black.withAlphaComponent(black))
    }

    static func themed(dark: NSColor, light: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .aqua ? light : dark
        })
    }
}

extension NSColor {
    convenience init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(
            srgbRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }
}

struct ColorDot: View {
    let hex: String
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(Color(hex: hex))
            .frame(width: size, height: size)
    }
}

struct IconButton<Icon: View>: View {
    let label: LocalizedStringKey
    var isOn = false
    var color = PanelStyle.tertiary
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            icon()
                .foregroundStyle(isOn || isHovered ? PanelStyle.primary : color)
                .frame(width: 28, height: 28)
                .background(isHovered ? PanelStyle.strongHover : .clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(label)
        .accessibilityLabel(label)
    }
}

struct SproutIcon: View {
    var color: Color = PanelStyle.green

    var body: some View {
        Canvas { context, size in
            let scale = CGAffineTransform(scaleX: size.width / 12, y: size.height / 12)
            var stem = Path()
            stem.move(to: CGPoint(x: 6, y: 11))
            stem.addLine(to: CGPoint(x: 6, y: 6.2))
            context.stroke(
                stem.applying(scale),
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.4 * size.width / 12, lineCap: .round)
            )
            var leaves = Path()
            leaves.move(to: CGPoint(x: 6, y: 6.4))
            leaves.addCurve(to: CGPoint(x: 10.2, y: 2.7), control1: CGPoint(x: 6.1, y: 4.1), control2: CGPoint(x: 7.7, y: 2.6))
            leaves.addCurve(to: CGPoint(x: 6, y: 6.4), control1: CGPoint(x: 10.1, y: 5), control2: CGPoint(x: 8.4, y: 6.5))
            leaves.closeSubpath()
            leaves.move(to: CGPoint(x: 6, y: 7.4))
            leaves.addCurve(to: CGPoint(x: 2.6, y: 4.5), control1: CGPoint(x: 5.9, y: 5.6), control2: CGPoint(x: 4.6, y: 4.4))
            leaves.addCurve(to: CGPoint(x: 6, y: 7.4), control1: CGPoint(x: 2.7, y: 6.3), control2: CGPoint(x: 4, y: 7.5))
            leaves.closeSubpath()
            context.fill(leaves.applying(scale), with: .color(color))
        }
        .accessibilityHidden(true)
    }
}
