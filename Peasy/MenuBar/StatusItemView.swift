import AppKit
import SwiftData
import SwiftUI

enum StatusItemMode: Equatable {
    case plain
    case indicator(remaining: Int)
    case added(colorHex: String)
}

/// What the status item shows: the sprout and how many of today's tasks are left.
struct StatusItemView: View {
    let model: PanelViewModel
    let onWidthChange: (CGFloat) -> Void

    @Query private var tasks: [TaskItem]
    @AppStorage(PanelSettings.showsTodayIndicatorKey) private var showsIndicator = true

    var body: some View {
        StatusItemLabel(mode: mode, onWidthChange: onWidthChange)
    }

    private var mode: StatusItemMode {
        if let added = model.addedConfirmation {
            return .added(colorHex: added)
        }
        guard showsIndicator else { return .plain }
        let remaining = TaskQueries.openTasks(in: .today, from: tasks, now: DayClock.shared.today).count
        return .indicator(remaining: remaining)
    }
}

struct StatusItemLabel: View {
    static let iconSize: CGFloat = 17

    let mode: StatusItemMode
    var onWidthChange: (CGFloat) -> Void = { _ in }

    var body: some View {
        content
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width in
                onWidthChange(width)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .plain:
            sprout
        case .indicator(let remaining):
            HStack(spacing: 5) {
                sprout
                if remaining > 0 {
                    Text(remaining, format: .number)
                        .monospacedDigit()
                }
            }
        case .added(let colorHex):
            HStack(spacing: 5) {
                CheckBadge(colorHex: colorHex, size: 16)
                Text("Added")
            }
        }
    }

    /// In the menu bar's text color, like the system's own icons.
    private var sprout: some View {
        SproutIcon(color: .primary)
            .frame(width: Self.iconSize, height: Self.iconSize)
    }
}

struct CheckBadge: View {
    let colorHex: String
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex))
            .frame(width: size, height: size)
            .overlay {
                Glyph(kind: .checkBold, size: (size * 4 / 7).rounded())
                    .foregroundStyle(.black)
            }
            .accessibilityHidden(true)
    }
}

/// Fills the status button and lets every click through to it.
final class StatusItemHostingView: NSHostingView<AnyView> {
    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }
}
