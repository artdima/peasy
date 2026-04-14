enum ProjectPalette {
    static let colors = ["#0A84FF", "#FF9F0A", "#30D158", "#BF5AF2", "#FF375F", "#64D2FF", "#FFD60A", "#AC8E68"]
    static let inbox = "#8E8E93"

    static func nextColor(excluding used: [String]) -> String {
        colors.first { !used.contains($0) } ?? colors[used.count % colors.count]
    }
}
