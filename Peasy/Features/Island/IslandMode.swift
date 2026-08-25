import CoreGraphics

enum IslandMode: Equatable {
    case plain
    case indicator(stage: PeaStage)
    case focus(title: String, colorHex: String, stage: PeaStage)
    case celebrating(colorHex: String, stage: PeaStage)
    case added(colorHex: String)

    var reserve: CGFloat {
        switch self {
        case .plain: 0
        case .indicator, .focus, .celebrating: 48
        case .added: 84
        }
    }

    var pea: (mood: BuddyView.Mood, stage: PeaStage)? {
        switch self {
        case .indicator(let stage): (.idle, stage)
        case .focus(_, _, let stage): (.focus, stage)
        case .celebrating(_, let stage): (.done, stage)
        case .plain, .added: nil
        }
    }

    var focusTitle: String? {
        if case .focus(let title, _, _) = self {
            return title
        }
        return nil
    }

    var focusColorHex: String? {
        if case .focus(_, let colorHex, _) = self {
            return colorHex
        }
        return nil
    }
}
