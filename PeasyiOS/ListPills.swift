import SwiftUI

struct ListPills: View {
    let projects: [Project]
    let tasks: [TaskItem]
    @Binding var selection: TaskList

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ListPill(title: Text("Today"), count: count(in: .today), isSelected: selection == .today, action: { selection = .today }) {
                        SproutIcon()
                            .frame(width: 16, height: 16)
                    }
                    .id(TaskList.today)

                    ListPill(title: Text("All"), count: count(in: .all), isSelected: selection == .all, action: { selection = .all }) {
                        ColorDot(hex: ProjectPalette.noProject)
                    }
                    .id(TaskList.all)

                    ForEach(projects) { project in
                        let list = TaskList.project(project.id)
                        ListPill(title: Text(project.name), count: count(in: list), isSelected: selection == list, action: { selection = list }) {
                            ColorDot(hex: project.colorHex)
                        }
                        .id(list)
                    }
                }
                .padding(.horizontal, 20)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                proxy.scrollTo(selection, anchor: .center)
            }
            .onChange(of: selection) { _, list in
                withAnimation(.snappy) {
                    proxy.scrollTo(list, anchor: .center)
                }
            }
        }
    }

    private func count(in list: TaskList) -> Int {
        TaskQueries.ownOpenTasks(in: list, from: tasks, now: DayClock.shared.today).count
    }
}

private struct ListPill<Icon: View>: View {
    let title: Text
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon()
                title
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? PanelStyle.selectedPrimary : PanelStyle.primary)
                    .lineLimit(1)
                if count > 0 {
                    Text(count, format: .number)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? PanelStyle.selectedTertiary : PanelStyle.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(minHeight: 34)
            .background(isSelected ? PanelStyle.pillSelection : PhoneStyle.pill, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
