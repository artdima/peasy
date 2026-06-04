import NotchKit
import SwiftData
import SwiftUI

struct IslandView: View {
    let presenter: NotchPresenter
    let model: NotchViewModel

    @Query private var tasks: [TaskItem]
    @AppStorage(PanelSettings.showsTodayIndicatorKey) private var showsIndicator = true
    @AppStorage(PanelSettings.showsBuddyKey) private var showsBuddy = true

    var body: some View {
        let mode = currentMode
        let geometry = presenter.geometry
        NotchCutoutLayout(
            cutoutWidth: geometry.notchWidth,
            gutterWidth: presenter.collapsedGutterWidth,
            pillHeight: geometry.collapsedHeight,
            edgeInset: 13
        ) {
            leading(for: mode)
        } trailing: {
            trailing(for: mode)
        }
        .foregroundStyle(PanelStyle.primary)
        .onChange(of: mode, initial: true) { _, mode in
            model.island = mode
        }
    }

    private var currentMode: IslandMode {
        let progress = TaskQueries.todayProgress(from: tasks)
        let open = progress.total - progress.done
        let growth = IslandMode.growth(done: progress.done, total: progress.total)
        if let added = model.addedConfirmation {
            return .added(colorHex: added)
        }
        if showsBuddy, let celebration = model.celebration {
            return .celebrating(colorHex: celebration.colorHex, open: open, growth: growth)
        }
        if showsBuddy, let id = model.focusedTaskID,
           let task = tasks.first(where: { $0.id == id && !$0.isDone }) {
            return .focus(
                title: task.title,
                colorHex: task.project?.colorHex ?? ProjectPalette.inbox,
                open: open,
                growth: growth
            )
        }
        if showsIndicator {
            let fraction = progress.total == 0 ? 0 : Double(progress.done) / Double(progress.total)
            return .indicator(progress: fraction, open: open)
        }
        return .plain
    }

    @ViewBuilder
    private func leading(for mode: IslandMode) -> some View {
        switch mode {
        case .plain:
            EmptyView()
        case .indicator(let progress, _):
            ProgressRing(progress: progress)
        case .focus(_, _, _, let growth):
            BuddyView(mood: .focus, growth: growth)
        case .celebrating(_, _, let growth):
            BuddyView(mood: .done, growth: growth)
        case .added(let colorHex):
            CheckBadge(colorHex: colorHex, size: 16)
        }
    }

    @ViewBuilder
    private func trailing(for mode: IslandMode) -> some View {
        switch mode {
        case .plain:
            EmptyView()
        case .indicator(_, let open), .focus(_, _, let open, _):
            CountLabel(value: open)
        case .celebrating(let colorHex, let open, _):
            HStack(spacing: 6) {
                CheckBadge(colorHex: colorHex, size: 14)
                    .transition(.scale.combined(with: .opacity))
                CountLabel(value: open)
            }
        case .added:
            Text("Added")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
    }
}

struct ProgressRing: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.22), lineWidth: 2)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(PanelStyle.primary, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .frame(width: 12.5, height: 12.5)
        .frame(width: 16, height: 16)
        .animation(.smooth, value: progress)
        .accessibilityHidden(true)
    }
}

struct CountLabel: View {
    let value: Int

    var body: some View {
        Text(value, format: .number)
            .font(.system(size: 13, weight: .semibold))
            .monospacedDigit()
            .frame(minWidth: 16, alignment: .trailing)
            .contentTransition(.numericText())
            .animation(.snappy, value: value)
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
