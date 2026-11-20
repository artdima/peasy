import SwiftUI

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
                .lineLimit(1)
        }
        .font(.system(size: 12))
        .foregroundStyle(PanelStyle.secondary)
        .fixedSize()
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
