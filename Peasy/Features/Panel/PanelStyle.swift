import AppKit
import SwiftUI

/// Colors of the panel and the windows around it. Each one resolves against the
/// appearance it is drawn in, so the theme is chosen by setting a window's appearance.
enum PanelStyle {
    /// The dark panel surface, also the ink of the morphing shape.
    static let ink = Color(hex: "#1C1C1E")
    static let primary = Color.themed(dark: "#E8E8ED", light: "#1D1D1F")
    static let title = Color.themed(dark: "#F2F2F7", light: "#1D1D1F")
    static let heading = Color.themed(dark: "#C9C9CE", light: "#6E6E73")
    static let secondary = Color.themed(dark: "#9A9AA0", light: "#6E6E73")
    static let tertiary = Color.themed(dark: "#9A9AA0", light: "#6E6E73")
    static let separator = Color.themed(white: 0.09, black: 0.08)
    static let hover = Color.themed(white: 0.06, black: 0.045)
    static let strongHover = Color.themed(white: 0.1, black: 0.07)
    static let pressed = Color.themed(white: 0.21, black: 0.1)
    static let selection = Color.themed(dark: NSColor(hex: "#3D5CCC"), light: NSColor.black.withAlphaComponent(0.075))
    static let pillSelection = selection
    static let selectedPrimary = Color.themed(dark: "#FFFFFF", light: "#1D1D1F")
    static let selectedTertiary = Color.themed(dark: NSColor.white.withAlphaComponent(0.85), light: NSColor(hex: "#6E6E73"))
    static let nameField = Color.themed(white: 0.12, black: 0.075)
    static let pillNameField = Color.themed(white: 0.13, black: 0.075)
    static let keyBorder = Color.themed(white: 0.18, black: 0.16)
    static let overdue = Color.themed(dark: "#FF5D4F", light: "#FF3B30")
    static let green = Color(hex: "#34C759")
    static let claude = Color.themed(dark: "#F0875F", light: "#C4532C")

    /// The light panel surface.
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
                .background(isHovered ? PanelStyle.strongHover : .clear, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
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
            let unit = size.width / 24
            let scale = CGAffineTransform(scaleX: unit, y: size.height / 24)
            var stem = Path()
            stem.move(to: CGPoint(x: 12, y: 22))
            stem.addLine(to: CGPoint(x: 12, y: 10))
            context.stroke(
                stem.applying(scale),
                with: .color(color),
                style: StrokeStyle(lineWidth: 2 * unit, lineCap: .round)
            )
            var leaves = Path()
            leaves.move(to: CGPoint(x: 12, y: 13))
            leaves.addCurve(to: CGPoint(x: 20, y: 5.5), control1: CGPoint(x: 12, y: 8.6), control2: CGPoint(x: 15.1, y: 5.5))
            leaves.addCurve(to: CGPoint(x: 12, y: 13), control1: CGPoint(x: 19.7, y: 10.1), control2: CGPoint(x: 16.7, y: 13))
            leaves.closeSubpath()
            leaves.move(to: CGPoint(x: 12, y: 10))
            leaves.addCurve(to: CGPoint(x: 4, y: 2.5), control1: CGPoint(x: 12, y: 5.6), control2: CGPoint(x: 8.9, y: 2.5))
            leaves.addCurve(to: CGPoint(x: 12, y: 10), control1: CGPoint(x: 4.3, y: 7.1), control2: CGPoint(x: 7.3, y: 10))
            leaves.closeSubpath()
            let scaled = leaves.applying(scale)
            context.fill(scaled, with: .color(color))
            context.stroke(
                scaled,
                with: .color(color),
                style: StrokeStyle(lineWidth: 1.5 * unit, lineCap: .round, lineJoin: .round)
            )
        }
        .accessibilityHidden(true)
    }
}
