import SwiftUI
import WidgetKit

@main
struct PeasyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayListWidget()
        TodayProgressWidget()
        ClaudeQuestionWidget()
        if #available(iOS 18.0, *) {
            NewTaskControl()
        }
    }
}
