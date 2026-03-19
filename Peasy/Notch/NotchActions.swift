struct NotchActions {
    var showAbout: () -> Void
    var openSettings: () -> Void
    var quit: () -> Void
    var collapse: () -> Void = {}
}
