struct PanelActions {
    var showAbout: () -> Void
    var checkForUpdates: () -> Void = {}
    var openSettings: () -> Void
    var quit: () -> Void
    var collapse: () -> Void = {}
}
