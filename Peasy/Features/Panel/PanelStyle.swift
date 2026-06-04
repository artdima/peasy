import SwiftUI

enum PanelStyle {
    static let primary = Color(hex: "#F5F5F7")
    static let secondary = Color(hex: "#98989F")
    static let tertiary = Color(hex: "#8E8E93")
    static let separator = Color.white.opacity(0.08)
    static let green = Color(hex: "#30D158")
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
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
                .background(.white.opacity(isHovered ? 0.08 : 0), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
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
