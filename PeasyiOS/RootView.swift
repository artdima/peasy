import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \TaskItem.order) private var tasks: [TaskItem]
    @State private var draft = ""

    var body: some View {
        let store = TaskStore(context: modelContext)
        NavigationStack {
            List {
                ForEach(tasks) { task in
                    Button {
                        store.toggle(task)
                    } label: {
                        Label {
                            Text(task.title)
                        } icon: {
                            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                        }
                    }
                }
                .onDelete { offsets in
                    offsets.map { tasks[$0] }.forEach { store.delete($0) }
                }
            }
            .navigationTitle(Text(verbatim: "Peasy"))
            .safeAreaInset(edge: .bottom) {
                TextField("New task", text: $draft)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        store.addTask(draft, to: .all)
                        draft = ""
                    }
                    .padding()
            }
        }
    }
}
