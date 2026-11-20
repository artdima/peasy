import Observation
import SwiftData

@Observable
final class AppModel {
    let sync = SyncMonitor()
    private(set) var container: ModelContainer?

    init() {
        sync.onStoreReloadNeeded = { [weak self] in self?.reloadStore() }
        sync.start()
        openStore()
    }

    func becameActive() {
        DayClock.shared.refresh()
    }

    private func openStore() {
        let container = Persistence.openStore(cloudKit: sync.isActive) { [sync] error in
            sync.storeFailed(error)
        }
        let store = TaskStore(context: container.mainContext)
        store.assignDistinctColors()
        store.moveTodayFlagsToDates()
        self.container = container
    }

    private func reloadStore() {
        // A second CloudKit container on the same store fails to register its export activity.
        container = nil
        Task { [weak self] in
            await Task.yield()
            self?.openStore()
        }
    }
}
