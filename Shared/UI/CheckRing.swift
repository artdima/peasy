import SwiftUI

struct CheckRing: View {
    enum Mark {
        case own
        case waiting
        case working
    }

    let color: Color
    let isOn: Bool
    var mark: Mark = .own
    var size: CGFloat = 22
    var hitSize: CGFloat = 30
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(color.opacity(isOn ? 1 : isHovered ? 0.24 : 0))
                switch mark {
                case .own:
                    Circle()
                        .strokeBorder(color, lineWidth: 2)
                case .waiting:
                    Circle()
                        .strokeBorder(color, style: StrokeStyle(lineWidth: 2, dash: [3, 2.4]))
                case .working:
                    Circle()
                        .strokeBorder(color.opacity(0.35), lineWidth: 2)
                    WorkingArc()
                }
                if mark != .own, !isOn {
                    Glyph(kind: .sparkle, size: size * 9 / 22, filled: true)
                        .foregroundStyle(PanelStyle.claude)
                }
                Glyph(kind: .check, size: size * 12 / 22)
                    .foregroundStyle(.black)
                    .opacity(isOn ? 1 : 0)
                    .scaleEffect(isOn ? 1 : 0.6)
            }
            .frame(width: size, height: size)
            .frame(width: hitSize, height: hitSize)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(.easeOut(duration: 0.18), value: isOn)
    }
}

private struct WorkingArc: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isSpinning = false

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.3)
            .stroke(PanelStyle.claude, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            .padding(1)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(reduceMotion ? nil : .linear(duration: 1.6).repeatForever(autoreverses: false), value: isSpinning)
            .onAppear {
                isSpinning = !reduceMotion
            }
    }
}
