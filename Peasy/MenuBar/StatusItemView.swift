import AppKit
import SwiftData
import SwiftUI

enum StatusItemMode: Equatable {
    case plain
    case indicator(stage: PeaStage, remaining: Int)
    case added(colorHex: String)
}

/// What the status item shows: the pea and today's count.
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
        let now = DayClock.shared.today
        let progress = TaskQueries.todayProgress(from: tasks, now: now)
        let remaining = TaskQueries.openTasks(in: .today, from: tasks, now: now).count
        return .indicator(stage: PeaStage(done: progress.done, total: progress.total), remaining: remaining)
    }
}

struct StatusItemLabel: View {
    static let peaHeight: CGFloat = 18

    let mode: StatusItemMode
    var onWidthChange: (CGFloat) -> Void = { _ in }

    @Environment(\.colorScheme) private var colorScheme

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
            pea(.pea)
        case .indicator(let stage, let remaining):
            HStack(spacing: 5) {
                pea(stage)
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

    /// The pea is light on a dark menu bar and dark on a light one.
    private func pea(_ stage: PeaStage) -> some View {
        let scale = Self.peaHeight / BuddyLayerView.size.height
        return BuddyView(stage: stage, scale: scale, isInverted: colorScheme == .light)
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
