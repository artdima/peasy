import CoreGraphics

enum IslandMode: Equatable {
    case plain
    case indicator(progress: Double, open: Int)
    case focus(title: String, colorHex: String, open: Int, growth: CGFloat)
    case celebrating(colorHex: String, open: Int, growth: CGFloat)
    case added(colorHex: String)

    var reserve: CGFloat {
        switch self {
        case .plain: 0
        case .indicator: 46
        case .focus: 60
        case .celebrating: 70
        case .added: 80
        }
    }

    var focusTitle: String? {
        if case .focus(let title, _, _, _) = self {
            return title
        }
        return nil
    }

    var focusColorHex: String? {
        if case .focus(_, let colorHex, _, _) = self {
            return colorHex
        }
        return nil
    }

    static func growth(done: Int, total: Int) -> CGFloat {
        let fraction = total == 0 ? 0 : CGFloat(done) / CGFloat(total)
        return 0.45 + 0.55 * fraction
    }
}
