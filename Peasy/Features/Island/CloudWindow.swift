import AppKit
import SwiftUI

@MainActor
final class CloudWindow {
    private static let margin: CGFloat = 24

    private let panel: NSPanel
    private let hostingView: NSHostingView<CloudView>
    private(set) var isVisible = false

    init() {
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.alphaValue = 0
        hostingView = NSHostingView(rootView: CloudView(title: "", colorHex: ProjectPalette.inbox))
        hostingView.sizingOptions = []
        let container = NSView()
        container.addSubview(hostingView)
        panel.contentView = container
    }

    func show(title: String, colorHex: String, below pill: CGRect) {
        hostingView.rootView = CloudView(title: title, colorHex: colorHex)
        let size = hostingView.fittingSize
        hostingView.frame = CGRect(origin: .zero, size: size)
        let frame = CGRect(
            x: pill.minX + 4 - Self.margin,
            y: pill.minY - 10 - size.height + Self.margin,
            width: size.width,
            height: size.height
        )
        panel.setFrame(frame, display: true)
        guard !isVisible else { return }
        isVisible = true
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard isVisible else { return }
        isVisible = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            panel.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, !self.isVisible else { return }
                self.panel.orderOut(nil)
            }
        }
    }
}

struct CloudView: View {
    let title: String
    let colorHex: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            ColorDot(hex: colorHex, size: 7)
                .padding(.top, 6)
            Text(verbatim: title)
                .font(.system(size: 13, weight: .medium))
                .lineSpacing(3.5)
                .padding(.bottom, 3.5)
                .foregroundStyle(PanelStyle.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(EdgeInsets(top: 8, leading: 11, bottom: 9, trailing: 13))
        .frame(maxWidth: 280, alignment: .leading)
        .fixedSize()
        .background(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.black)
                RoundedRectangle(cornerRadius: 2)
                    .fill(.black)
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(45))
                    .offset(x: 15, y: -5)
            }
            .shadow(color: Color(red: 16 / 255, green: 18 / 255, blue: 24 / 255).opacity(0.4), radius: 15, y: 12)
        }
        .padding(24)
        .environment(\.colorScheme, .dark)
    }
}
