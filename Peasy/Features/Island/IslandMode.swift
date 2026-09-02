import CoreGraphics

enum IslandMode: Equatable {
    case plain
    case indicator(stage: PeaStage)
    case added(colorHex: String)

    var reserve: CGFloat {
        switch self {
        case .plain: 0
        case .indicator: 48
        case .added: 84
        }
    }
}
