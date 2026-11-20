import SwiftUI

struct ListPills: View {
    let projects: [Project]
    let tasks: [TaskItem]
    @Binding var selection: TaskList

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    PhonePill(title: Text("Today"), count: count(in: .today), isSelected: selection == .today, action: { selection = .today }) {
                        SproutIcon()
                            .frame(width: 16, height: 16)
                    }
                    .id(TaskList.today)

                    PhonePill(title: Text("All"), count: count(in: .all), isSelected: selection == .all, action: { selection = .all }) {
                        ColorDot(hex: ProjectPalette.noProject)
                    }
                    .id(TaskList.all)

                    ForEach(projects) { project in
                        let list = TaskList.project(project.id)
                        PhonePill(title: Text(project.name), count: count(in: list), isSelected: selection == list, action: { selection = list }) {
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
