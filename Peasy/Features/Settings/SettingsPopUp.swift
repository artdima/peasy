import AppKit
import SwiftUI

/// A flat pop-up button as in the mockups; the choices open in a native menu.
struct SettingsPopUp<Value: Hashable>: View {
    let options: [(value: Value, title: String)]
    @Binding var selection: Value

    @State private var isHovered = false

    var body: some View {
        Button(action: showMenu) {
            Text(verbatim: options.first { $0.value == selection }?.title ?? "")
                .font(.system(size: 13))
                .foregroundStyle(PanelStyle.primary)
                .lineLimit(1)
                .padding(.leading, 12)
                .padding(.trailing, 30)
                .frame(height: 28)
                .background(isHovered ? SettingsStyle.controlHover : SettingsStyle.control, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(alignment: .trailing) {
                    UpDownChevron()
                        .stroke(SettingsStyle.chevron, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                        .frame(width: 9, height: 12)
                        .padding(.trailing, 9)
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { isHovered = $0 }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.appearance = NSApp.keyWindow?.effectiveAppearance
        var current: NSMenuItem?
        for option in options {
            let item = ClosureMenuItem(title: option.title) { selection = option.value }
            if option.value == selection {
                item.state = .on
                current = item
            }
            menu.addItem(item)
        }
        menu.popUp(positioning: current, at: NSEvent.mouseLocation, in: nil)
    }
}

struct UpDownChevron: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = CGAffineTransform(scaleX: rect.width / 9, y: rect.height / 12)
        var path = Path()
        path.move(to: CGPoint(x: 1.5, y: 4.5))
        path.addLine(to: CGPoint(x: 4.5, y: 1.5))
        path.addLine(to: CGPoint(x: 7.5, y: 4.5))
        path.move(to: CGPoint(x: 1.5, y: 7.5))
        path.addLine(to: CGPoint(x: 4.5, y: 10.5))
        path.addLine(to: CGPoint(x: 7.5, y: 7.5))
        return path.applying(scale.translatedBy(x: rect.minX, y: rect.minY))
    }
}

final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(runHandler), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is unavailable")
    }

    @objc private func runHandler() {
        handler()
    }
}
