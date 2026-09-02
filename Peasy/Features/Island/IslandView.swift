import NotchKit
import SwiftData
import SwiftUI

struct IslandView: View {
    let presenter: NotchPresenter
    let model: NotchViewModel

    @Query private var tasks: [TaskItem]
    @AppStorage(PanelSettings.showsTodayIndicatorKey) private var showsIndicator = true

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
        let progress = TaskQueries.todayProgress(from: tasks, now: DayClock.shared.today)
        let stage = PeaStage(done: progress.done, total: progress.total)
        if let added = model.addedConfirmation {
            return .added(colorHex: added)
        }
        if showsIndicator {
            return .indicator(stage: stage)
        }
        return .plain
    }

    @ViewBuilder
    private func leading(for mode: IslandMode) -> some View {
        switch mode {
        case .plain:
            EmptyView()
        case .indicator(let stage):
            BuddyView(stage: stage, scale: min(1, presenter.geometry.collapsedHeight / BuddyLayerView.size.height))
                .offset(x: -2)
        case .added(let colorHex):
            CheckBadge(colorHex: colorHex, size: 16)
        }
    }

    @ViewBuilder
    private func trailing(for mode: IslandMode) -> some View {
        switch mode {
        case .plain:
            EmptyView()
        case .indicator:
            Color.clear
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
