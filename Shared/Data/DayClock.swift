import Foundation
import Observation

/// Today's contents depend on the date, which no query notices changing.
@MainActor
@Observable
final class DayClock {
    static let shared = DayClock()

    private(set) var today = Calendar.current.startOfDay(for: .now)
    @ObservationIgnored private var observer: NSObjectProtocol?

    private init() {
        observer = NotificationCenter.default.addObserver(forName: .NSCalendarDayChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.today = Calendar.current.startOfDay(for: .now)
            }
        }
    }
}
