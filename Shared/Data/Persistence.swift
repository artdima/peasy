import SwiftData

enum Persistence {
    static let schema = Schema([Project.self, TaskItem.self])

    static func makeContainer(inMemory: Bool = false, cloudKit: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: cloudKit ? .private(CloudSync.containerIdentifier) : .none
        )
        return try ModelContainer(for: schema, configurations: configuration)
    }

    static func openStore(cloudKit: Bool, onCloudKitFailure: (Error) -> Void = { _ in }) -> ModelContainer {
        if cloudKit {
            do {
                return try makeContainer(cloudKit: true)
            } catch {
                onCloudKitFailure(error)
            }
        }
        do {
            return try makeContainer()
        } catch {
            fatalError("Failed to open the task store: \(error)")
        }
    }
}
