#if os(iOS)
import Foundation
import Observation
import SwiftData
import WidgetKit

enum SharedStore {
    static var appContainer: ModelContainer?

    private static var localContainer: ModelContainer?
    private static let defaults = UserDefaults(suiteName: "group.com.artdima.Peasy")
    private static let outsideChangeKey = "storeChangedOutsideApp"

    static func read<Result>(_ body: (TaskStore) -> Result) -> Result? {
        guard let context = context() else { return nil }
        return body(TaskStore(context: context))
    }

    @discardableResult
    static func write<Result>(_ body: (TaskStore) -> Result) -> Result? {
        guard let context = context() else { return nil }
        let result = body(TaskStore(context: context))
        if appContainer == nil {
            defaults?.set(true, forKey: outsideChangeKey)
        }
        WidgetCenter.shared.reloadAllTimelines()
        return result
    }

    /// The app reschedules reminders after every save; the widget extension has to do it itself.
    static func rescheduleRemindersOutsideApp() async {
        guard appContainer == nil, let requests = read({ Reminders.requests(for: $0.allTasks(), now: .now) }) else { return }
        await Reminders.replacePending(with: requests)
    }

    /// The app's context keeps the objects it has loaded, so it has to reopen the
    /// store to see what the widget extension changed.
    static func takeOutsideChange() -> Bool {
        guard defaults?.bool(forKey: outsideChangeKey) == true else { return false }
        defaults?.removeObject(forKey: outsideChangeKey)
        return true
    }

    private static func context() -> ModelContext? {
        if let appContainer {
            return appContainer.mainContext
        }
        if localContainer == nil {
            localContainer = try? Persistence.makeContainer()
        }
        return localContainer.map { ModelContext($0) }
    }
}

@Observable
final class NewTaskPrompt {
    static let shared = NewTaskPrompt()

    var isPresented = false
}

nonisolated enum AppLink: Hashable {
    case today
    case task(UUID)

    static let scheme = "peasy"

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }
        switch url.host() {
        case "today":
            self = .today
        case "task":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            self = .task(id)
        default:
            return nil
        }
    }

    var url: URL {
        switch self {
        case .today: URL(string: "\(Self.scheme)://today")!
        case .task(let id): URL(string: "\(Self.scheme)://task/\(id.uuidString)")!
        }
    }
}
#endif
