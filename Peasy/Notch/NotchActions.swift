struct NotchActions {
    var openSettings: () -> Void
    var quit: () -> Void
    var collapse: () -> Void = {}
}
