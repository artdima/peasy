import SwiftUI

struct SyncSection: View {
    let sync: SyncMonitor
    let folderSync: FolderSync

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsCard(note: note) {
                SettingsRow {
                    Glyph(kind: .cloud, size: 18)
                        .foregroundStyle(Color(hex: "#64D2FF"))
                        .frame(width: 28, height: 28)
                        .background(SettingsStyle.iconTile, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("iCloud sync")
                            .settingsTitle()
                        Text("Tasks and projects on all your Macs")
                            .settingsSubtitle()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Toggle("iCloud sync", isOn: Binding(get: { sync.isActive }, set: { sync.setEnabled($0) }))
                        .toggleStyle(PeasySwitchStyle())
                        .disabled(!sync.isAvailable)
                        .opacity(sync.isAvailable ? 1 : 0.4)
                }
                if sync.isActive {
                    SettingsRow(minHeight: 44, separated: true) {
                        Text("Status")
                            .settingsTitle()
                            .frame(maxWidth: .infinity, alignment: .leading)
                        SyncStatusLabel(status: sync.status)
                        IconButton(label: "Sync now", color: PanelStyle.secondary) {
                            sync.syncNow()
                        } icon: {
                            Glyph(kind: .refresh, size: 14)
                        }
                        .disabled(!sync.canSyncNow)
                        .opacity(sync.canSyncNow ? 1 : 0.4)
                    }
                }
            }
            FolderSyncCard(folderSync: folderSync)
        }
    }

    private var note: LocalizedStringKey {
        switch sync.status {
        case .unavailable: "This build of Peasy is signed without iCloud, so tasks are stored only on this Mac."
        case .off: "Sync is off — tasks are stored only on this Mac."
        case .noAccount: "Sign in to iCloud in System Settings to sync your tasks."
        default: "Peasy uses the iCloud account you’re signed in to on this Mac. Tasks are kept in your private iCloud storage."
        }
    }
}
