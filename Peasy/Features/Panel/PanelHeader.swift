import SwiftUI

struct PanelHeader: View {
    @Bindable var model: NotchViewModel
    let onOpenSettings: () -> Void

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
            IconButton(label: "Pin panel", isOn: model.isPinned) {
                model.isPinned.toggle()
            } icon: {
                Glyph(kind: .pin, size: 18, filled: model.isPinned)
            }
            .accessibilityAddTraits(model.isPinned ? .isSelected : [])
        }
        .padding(.leading, 24)
        .padding(.trailing, 20)
    }

    static func dateTitle(for date: Date = .now) -> String {
        let text = date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
