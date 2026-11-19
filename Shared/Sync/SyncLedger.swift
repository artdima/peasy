/// Set when the user deletes something on this Mac, so a store emptied by hand
/// is not mistaken for a wiped one.
enum SyncLedger {
    static var hasLocalDeletions = false
}
