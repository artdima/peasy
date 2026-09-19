import SwiftUI

struct FolderSyncCard: View {
    let folderSync: FolderSync

    var body: some View {
        SettingsCard(note: note) {
            SettingsRow {
                Glyph(kind: .folder, size: 18)
                    .foregroundStyle(Color(hex: "#0A84FF"))
                    .frame(width: 28, height: 28)
                    .background(SettingsStyle.iconTile, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync folder")
                        .settingsTitle()
                    Text("Dropbox, Yandex Disk, Google Drive or another synced folder")
                        .settingsSubtitle()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("Sync folder", isOn: Binding(get: { folderSync.isOn }, set: { setOn($0) }))
                    .toggleStyle(PeasySwitchStyle())
            }
            if folderSync.isOn {
                SettingsRow(minHeight: 44, separated: true) {
                    Text("Folder")
                        .settingsTitle()
                    Text(verbatim: folderSync.folderName ?? "")
                        .font(.system(size: 12))
                        .foregroundStyle(PanelStyle.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    SettingsTextButton(title: "Change…") {
                        Task { @MainActor in folderSync.chooseFolder() }
                    }
                }
                SettingsRow(minHeight: 44, separated: true) {
                    Text("Status")
                        .settingsTitle()
                        .frame(maxWidth: .infinity, alignment: .leading)
                    FolderSyncStatusLabel(status: folderSync.status)
                    IconButton(label: "Sync now", color: PanelStyle.secondary) {
                        Task { await folderSync.syncNow() }
                    } icon: {
                        Glyph(kind: .refresh, size: 14)
                    }
                }
            }
        }
    }

    /// The open panel runs after the switch has finished animating.
    private func setOn(_ isOn: Bool) {
        if isOn {
            Task { @MainActor in folderSync.chooseFolder() }
        } else {
            folderSync.turnOff()
        }
    }

    private var note: LocalizedStringKey {
        switch folderSync.status {
        case .off:
            return "For a Mac with another Apple ID or without iCloud. Choose the same folder on every Mac."
        case .paused(let name):
            return "\(name) already syncs this iCloud account through the folder, so this Mac gets its tasks through iCloud."
        case .noAccess:
            return "Peasy lost access to the folder. Choose it again."
        case .failed(let message):
            return "Can’t sync with the folder: \(message)"
        case .waiting, .idle:
            let names = folderSync.peers.map(\.name)
            if names.isEmpty {
                return "Choose this folder on your other Macs too."
            }
            return "Also syncing here: \(ListFormatter.localizedString(byJoining: names))"
        }
    }
}

struct FolderSyncStatusLabel: View {
    let status: FolderSyncStatus

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)
            text
                .lineLimit(1)
        }
        .font(.system(size: 12))
        .foregroundStyle(PanelStyle.secondary)
        .fixedSize()
    }

    private var text: Text {
        switch status {
        case .idle(let date): Text(verbatim: SyncedDay.text(for: date))
        case .waiting: Text("Waiting to sync")
        case .paused: Text("Paused")
        case .noAccess: Text("No access to the folder")
        case .failed: Text("Sync error")
        case .off: Text(verbatim: "")
        }
    }

    private var dotColor: Color {
        switch status {
        case .idle: PanelStyle.green
        case .paused, .noAccess: Color(hex: "#FF9F0A")
        case .failed: Color(hex: "#FF453A")
        case .waiting, .off: PanelStyle.tertiary
        }
    }
}

struct SettingsTextButton: View {
    let title: LocalizedStringKey
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundStyle(PanelStyle.primary)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(isHovered ? PanelStyle.strongHover : PanelStyle.hover, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .fixedSize()
    }
}
