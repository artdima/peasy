enum PeaStage: CaseIterable {
    case pea
    case hatched
    case sprout
    case grown
    case bud
    case bloom

    init(done: Int, total: Int) {
        guard total > 0, done > 0 else {
            self = .pea
            return
        }
        guard done < total else {
            self = .bloom
            return
        }
        switch Double(done) / Double(total) {
        case ..<0.25: self = .hatched
        case ..<0.5: self = .sprout
        case ..<0.75: self = .grown
        default: self = .bud
        }
    }
}
