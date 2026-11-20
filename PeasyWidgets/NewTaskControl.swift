import AppIntents
import SwiftUI
import WidgetKit

@available(iOS 18.0, *)
struct NewTaskControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "NewTask") {
            ControlWidgetButton(action: NewTaskIntent()) {
                Label("New task", systemImage: "plus.circle")
            }
        }
        .displayName("New task")
        .description("Opens Peasy with a new task.")
    }
}
