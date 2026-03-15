import SwiftUI

struct SettingsView: View {
    @AppStorage(DisplayPreference.storageKey) private var display = DisplayPreference.builtIn
    @AppStorage(OpenDelay.storageKey) private var openDelay = OpenDelay.normal
    @AppStorage(PanelSettings.showsCompletedKey) private var showsCompleted = true
    @State private var launchAtLogin = LaunchAtLogin()

    var body: some View {
        Form {
            Section {
                Toggle("Open at login", isOn: Binding(
                    get: { launchAtLogin.isOn },
                    set: { launchAtLogin.set($0) }
                ))
                if launchAtLogin.needsApproval {
                    HStack {
                        Text("Allow Peasy in Login Items to finish.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Settings…", action: launchAtLogin.openSystemSettings)
                    }
                }
                if let message = launchAtLogin.errorMessage {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }

            Section("Panel") {
                Picker("Show on", selection: $display) {
                    ForEach(DisplayPreference.allCases) { preference in
                        Text(preference.title).tag(preference)
                    }
                }
                Picker("Open after hovering", selection: $openDelay) {
                    ForEach(OpenDelay.allCases) { delay in
                        Text(delay.title).tag(delay)
                    }
                }
                Toggle("Show completed tasks", isOn: $showsCompleted)
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            launchAtLogin.refresh()
        }
    }
}

#Preview {
    SettingsView()
}
