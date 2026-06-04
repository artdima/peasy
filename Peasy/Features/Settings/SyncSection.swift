import SwiftUI

struct SyncSection: View {
    let sync: SyncMonitor

    var body: some View {
        SettingsSection(title: "iCloud", note: note) {
            SettingsRow {
                Glyph(kind: .cloud, size: 18)
                    .foregroundStyle(Color(hex: "#64D2FF"))
                    .frame(width: 28, height: 28)
                    .background(Color(hex: "#2C2C2E"), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("iCloud sync")
                        .settingsTitle()
                    Text("Tasks and projects on all your Macs")
                        .font(.system(size: 11.5))
                        .foregroundStyle(PanelStyle.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Toggle("iCloud sync", isOn: Binding(get: { sync.isActive }, set: { sync.setEnabled($0) }))
                    .toggleStyle(PeasySwitchStyle())
                    .disabled(!sync.isAvailable)
                    .opacity(sync.isAvailable ? 1 : 0.4)
            }
            if sync.isActive {
                SettingsDivider()
                SettingsRow(minHeight: 44) {
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

struct SyncStatusLabel: View {
    let status: SyncStatus

    var body: some View {
        HStack(spacing: 7) {
            if status == .syncing {
                SyncSpinner()
            } else {
                Circle()
                    .fill(dotColor)
                    .frame(width: 7, height: 7)
            }
            text
        }
        .font(.system(size: 12))
        .foregroundStyle(PanelStyle.secondary)
    }

    private var text: Text {
        switch status {
        case .syncing: Text("Syncing…")
        case .idle(let date?): Text(verbatim: SyncedDay.text(for: date))
        case .idle(nil): Text("Waiting to sync")
        case .offline: Text("No connection")
        case .noAccount: Text("Not signed in to iCloud")
        case .failed: Text("Sync error")
        case .off, .unavailable: Text(verbatim: "")
        }
    }

    private var dotColor: Color {
        switch status {
        case .idle(.some): PanelStyle.green
        case .offline, .noAccount: Color(hex: "#FF9F0A")
        case .failed: Color(hex: "#FF453A")
        default: PanelStyle.tertiary
        }
    }
}

struct SyncSpinner: View {
    @State private var isSpinning = false

    var body: some View {
        Glyph(kind: .spinner, size: 12)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .animation(.linear(duration: 0.9).repeatForever(autoreverses: false), value: isSpinning)
            .onAppear { isSpinning = true }
    }
}

enum SyncedDay: Equatable {
    case today
    case yesterday
    case earlier

    init(_ date: Date, now: Date = .now, calendar: Calendar = .current) {
        if calendar.isDate(date, inSameDayAs: now) {
            self = .today
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
                  calendar.isDate(date, inSameDayAs: yesterday) {
            self = .yesterday
        } else {
            self = .earlier
        }
    }

    static func text(for date: Date) -> String {
        let time = date.formatted(date: .omitted, time: .shortened)
        switch SyncedDay(date) {
        case .today: return String(localized: "Synced today at \(time)")
        case .yesterday: return String(localized: "Synced yesterday at \(time)")
        case .earlier: return String(localized: "Synced \(date.formatted(.dateTime.day().month().hour().minute()))")
        }
    }
}
