import SwiftUI
import UIKit
import UniformTypeIdentifiers
import UserNotifications

enum PhoneSettings {
    static let multilineTasksKey = "multilineTasks"
    static let showsBadgeKey = "showsBadge"
}

extension AppTheme {
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .dark: .dark
        case .light: .light
        }
    }
}

struct SettingsSheet: View {
    @Environment(SyncMonitor.self) private var sync
    @Environment(FolderSync.self) private var folderSync
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark
    @AppStorage(PhoneSettings.multilineTasksKey) private var multilineTasks = true
    @AppStorage(PhoneSettings.showsBadgeKey) private var showsBadge = true
    @AppStorage(ClaudeNotifications.needsHelpKey) private var notifiesNeedsHelp = true
    @AppStorage(ClaudeNotifications.finishedKey) private var notifiesFinished = false
    @AppStorage(FolderSync.deviceNameKey) private var deviceName = ""
    @State private var notificationStatus: UNAuthorizationStatus?
    @State private var isChoosingFolder = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("iCloud sync", isOn: Binding(get: { sync.isActive }, set: { sync.setEnabled($0) }))
                        .disabled(!sync.isAvailable)
                    if sync.isActive {
                        LabeledContent("Status") {
                            SyncStatusLabel(status: sync.status)
                        }
                        Button("Sync now") {
                            sync.syncNow()
                        }
                        .disabled(!sync.canSyncNow)
                    }
                } footer: {
                    Text(syncNote)
                }

                Section {
                    if folderSync.isOn {
                        LabeledContent("Folder") {
                            Text(verbatim: folderSync.folderName ?? "")
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        LabeledContent("Status") {
                            FolderSyncStatusLabel(status: folderSync.status)
                        }
                        Button("Sync now") {
                            Task {
                                await folderSync.syncNow()
                            }
                        }
                        Button("Change…") {
                            isChoosingFolder = true
                        }
                        Button("Turn Off", role: .destructive) {
                            folderSync.turnOff()
                        }
                    } else {
                        Button("Choose Folder…") {
                            isChoosingFolder = true
                        }
                    }
                    TextField("Device name", text: $deviceName, prompt: Text(verbatim: UIDevice.current.name))
                } header: {
                    Text("Sync folder")
                } footer: {
                    Text(folderNote)
                }

                Section {
                    Picker("Appearance", selection: $theme) {
                        ForEach(AppTheme.allCases) { theme in
                            Text(theme.title)
                                .tag(theme)
                        }
                    }
                    Toggle("Multiline tasks", isOn: $multilineTasks)
                    Button {
                        open(UIApplication.openSettingsURLString)
                    } label: {
                        LabeledContent("Language") {
                            Image(systemName: "arrow.up.forward.app")
                        }
                    }
                } footer: {
                    Text("Peasy follows the language chosen for it in Settings.")
                }

                Section {
                    LabeledContent("Notifications") {
                        notificationText
                    }
                    Toggle("Badge with today’s tasks", isOn: $showsBadge)
                    Button("Open Settings") {
                        open(UIApplication.openNotificationSettingsURLString)
                    }
                } footer: {
                    Text("Reminders for tasks with a time.")
                }

                Section {
                    Text("Claude works with your tasks through Peasy on your Mac. Tasks you hand to Claude here reach it through iCloud.")
                        .foregroundStyle(.secondary)
                    Toggle("Claude needs help", isOn: $notifiesNeedsHelp)
                    Toggle("Claude finished a task", isOn: $notifiesFinished)
                } header: {
                    Text(verbatim: "Claude")
                } footer: {
                    Text("Notifications on this iPhone. If your Mac already tells you, turn them off here.")
                }

                Section {
                    LabeledContent {
                        Text("Version \(Self.version)")
                    } label: {
                        Text(verbatim: "Peasy")
                    }
                } footer: {
                    Text("Little tasks, big growth.")
                }
            }
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await refreshNotificationStatus()
            }
            .fileImporter(isPresented: $isChoosingFolder, allowedContentTypes: [.folder]) { result in
                if case .success(let url) = result {
                    folderSync.useFolder(url)
                }
            }
            .onChange(of: showsBadge) { _, isOn in
                askForNotifications(isOn)
            }
            .onChange(of: notifiesNeedsHelp) { _, isOn in
                askForNotifications(isOn)
            }
            .onChange(of: notifiesFinished) { _, isOn in
                askForNotifications(isOn)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await refreshNotificationStatus()
                    }
                }
            }
        }
    }

    private var syncNote: LocalizedStringKey {
        switch sync.status {
        case .unavailable: "This build of Peasy is signed without iCloud, so tasks are stored only on this iPhone."
        case .off: "Sync is off — tasks are stored only on this iPhone."
        case .noAccount: "Sign in to iCloud in Settings to sync your tasks."
        default: "Peasy uses the iCloud account you’re signed in to on this iPhone. Tasks are kept in your private iCloud storage."
        }
    }

    private var folderNote: LocalizedStringKey {
        switch folderSync.status {
        case .off:
            return "For devices with another Apple ID or without iCloud. Choose the same folder of Dropbox, Yandex Disk or another app in Files on each of them."
        case .paused(let name):
            return "\(name) already syncs this iCloud account through the folder, so this iPhone gets its tasks through iCloud."
        case .noAccess:
            return "Peasy lost access to the folder. Choose it again."
        case .failed(let message):
            return "Can’t sync with the folder: \(message)"
        case .waiting, .idle:
            let names = folderSync.peers.map(\.name)
            if names.isEmpty {
                return "Choose this folder on your other devices too."
            }
            return "Also syncing here: \(ListFormatter.localizedString(byJoining: names))"
        }
    }

    private var notificationText: Text {
        switch notificationStatus {
        case .authorized, .provisional, .ephemeral: Text("Allowed")
        case .denied: Text("Not allowed")
        default: Text("Not set")
        }
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private func open(_ string: String) {
        if let url = URL(string: string) {
            openURL(url)
        }
    }

    private func askForNotifications(_ isOn: Bool) {
        guard isOn else { return }
        Task {
            _ = await Reminders.shared.requestPermission()
            await refreshNotificationStatus()
        }
    }

    private func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
