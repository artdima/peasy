import SwiftUI
import UIKit
import UserNotifications

enum PhoneSettings {
    static let multilineTasksKey = "multilineTasks"
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.dark
    @AppStorage(PhoneSettings.multilineTasksKey) private var multilineTasks = true
    @State private var notificationStatus: UNAuthorizationStatus?

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
                    Button("Open Settings") {
                        open(UIApplication.openNotificationSettingsURLString)
                    }
                } footer: {
                    Text("Reminders for tasks with a time.")
                }

                Section {
                    Text("Claude works with your tasks through Peasy on your Mac. Tasks you hand to Claude here reach it through iCloud.")
                        .foregroundStyle(.secondary)
                } header: {
                    Text(verbatim: "Claude")
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

    private func refreshNotificationStatus() async {
        notificationStatus = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }
}
