import SwiftData
import SwiftUI

struct NotchContentView: View {
    let model: NotchViewModel

    @Environment(\.modelContext) private var modelContext
    @Query(sort: [SortDescriptor(\Project.order), SortDescriptor(\Project.createdAt)])
    private var projects: [Project]
    @AppStorage("selectedProjectID") private var selectedProjectID = ""

    var body: some View {
        let store = TaskStore(context: modelContext)
        VStack(alignment: .leading, spacing: 10) {
            if let project = selectedProject {
                Text(project.name)
                    .font(.headline)
                TaskListView(project: project, store: store)
            } else {
                FirstProjectView { name in
                    if let project = store.createProject(named: name) {
                        selectedProjectID = project.id.uuidString
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 6, leading: 16, bottom: 14, trailing: 16))
        .frame(width: NotchViewModel.contentWidth, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.height
        } action: { height in
            model.setContentHeight(height)
        }
    }

    private var selectedProject: Project? {
        projects.first { $0.id.uuidString == selectedProjectID } ?? projects.first
    }
}
