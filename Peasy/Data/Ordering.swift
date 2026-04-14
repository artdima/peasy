import Foundation

protocol Orderable: AnyObject {
    var order: Double { get set }
}

extension Project: Orderable {}
extension TaskItem: Orderable {}

enum Ordering {
    static let minimumGap = 1e-6

    static func orders(count: Int, between lower: Double?, and upper: Double?) -> [Double] {
        guard count > 0 else { return [] }
        switch (lower, upper) {
        case let (lower?, upper?):
            let step = (upper - lower) / Double(count + 1)
            return (1...count).map { lower + step * Double($0) }
        case let (lower?, nil):
            return (1...count).map { lower + Double($0) }
        case let (nil, upper?):
            return (1...count).map { upper - Double(count + 1 - $0) }
        case (nil, nil):
            return (0..<count).map(Double.init)
        }
    }

    @discardableResult
    static func move<Item: Orderable>(_ items: [Item], from source: IndexSet, to destination: Int) -> Bool {
        let moved = source.sorted().map { items[$0] }
        guard !moved.isEmpty else { return false }
        var reordered = items.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let shift = source.filter { $0 < destination }.count
        let insertIndex = min(max(destination - shift, 0), reordered.count)
        reordered.insert(contentsOf: moved, at: insertIndex)

        let lower = insertIndex > 0 ? reordered[insertIndex - 1].order : nil
        let upperIndex = insertIndex + moved.count
        let upper = upperIndex < reordered.count ? reordered[upperIndex].order : nil
        for (item, order) in zip(moved, orders(count: moved.count, between: lower, and: upper)) {
            item.order = order
        }
        return zip(reordered, reordered.dropFirst()).contains { $1.order - $0.order < minimumGap }
    }

    static func renumber<Item: Orderable>(_ items: [Item]) {
        for (index, item) in items.sorted(by: { $0.order < $1.order }).enumerated() {
            item.order = Double(index)
        }
    }
}
