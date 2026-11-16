struct PanelActions {
    var showAbout: () -> Void
    var checkForUpdates: () -> Void = {}
    var newTask: () -> Void = {}
    var openSettings: () -> Void
    var quit: () -> Void
    var collapse: () -> Void = {}
}
