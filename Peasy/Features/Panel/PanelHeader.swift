import SwiftUI

struct PanelHeader: View {
    let onOpenSettings: () -> Void
    let onQuit: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Text(Self.dateTitle())
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(PanelStyle.heading)
            Spacer()
            IconButton(label: "Settings") {
                onOpenSettings()
            } icon: {
                Glyph(kind: .gear, size: 18)
            }
            IconButton(label: "Quit Peasy") {
                onQuit()
            } icon: {
                Glyph(kind: .power, size: 18)
            }
        }
        .padding(.leading, 24)
        .padding(.trailing, 20)
    }

    static func dateTitle(for date: Date = .now) -> String {
        let text = date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
