import SwiftUI

enum ProjectPalette {
    static let colors = ["#0A84FF", "#FF9F0A", "#30D158", "#BF5AF2", "#FF375F", "#64D2FF", "#FFD60A", "#AC8E68"]
    static let inbox = "#8E8E93"

    static func nextColor(excluding used: [String]) -> String {
        colors.first { !used.contains($0) } ?? colors[used.count % colors.count]
    }

    static func name(of hex: String) -> LocalizedStringKey {
        switch hex {
        case "#0A84FF": "Blue"
        case "#FF9F0A": "Orange"
        case "#30D158": "Green"
        case "#BF5AF2": "Purple"
        case "#FF375F": "Pink"
        case "#64D2FF": "Cyan"
        case "#FFD60A": "Yellow"
        case "#AC8E68": "Brown"
        default: "Color"
        }
    }
}
