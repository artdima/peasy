import AppIntents

nonisolated struct PeasyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AddTaskIntent(),
            phrases: [
                "Add a task to \(.applicationName)",
                "Add a \(.applicationName) task",
                "New task in \(.applicationName)",
            ],
            shortTitle: "Add Task",
            systemImageName: "plus.circle"
        )
    }
}
