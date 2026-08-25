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
            edgeInset: 15
        ) {
            leading(for: mode)
        } trailing: {
            trailing(for: mode)
        }
        .foregroundStyle(PanelStyle.onBlack)
        .background(.black)
        .environment(\.colorScheme, .dark)
        .onChange(of: mode, initial: true) { _, mode in
            model.island = mode
        }
    }

    private var currentMode: IslandMode {
        let progress = TaskQueries.todayProgress(from: tasks)
        let stage = PeaStage(done: progress.done, total: progress.total)
        if let added = model.addedConfirmation {
            return .added(colorHex: added)
        }
        if showsBuddy, let celebration = model.celebration {
            return .celebrating(colorHex: celebration.colorHex, stage: stage)
        }
        if showsBuddy, let id = model.focusedTaskID,
           let task = tasks.first(where: { $0.id == id && !$0.isDone }) {
            return .focus(
                title: task.title,
                colorHex: task.project?.colorHex ?? ProjectPalette.inbox,
                stage: stage
            )
        }
        if showsIndicator {
            return .indicator(stage: stage)
        }
        return .plain
    }

    @ViewBuilder
    private func leading(for mode: IslandMode) -> some View {
        if case .added(let colorHex) = mode {
            CheckBadge(colorHex: colorHex, size: 16)
        } else if let pea = mode.pea {
            BuddyView(
                mood: pea.mood,
                stage: pea.stage,
                scale: min(1, presenter.geometry.collapsedHeight / BuddyLayerView.size.height)
            )
            .offset(x: -2)
        }
    }

    @ViewBuilder
    private func trailing(for mode: IslandMode) -> some View {
        switch mode {
        case .plain:
            EmptyView()
        case .indicator, .focus:
            Color.clear
        case .celebrating(let colorHex, _):
            CheckBadge(colorHex: colorHex, size: 14)
                .transition(.scale.combined(with: .opacity))
        case .added:
            Text("Added")
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
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
