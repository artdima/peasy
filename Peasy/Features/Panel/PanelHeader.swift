import SwiftUI

struct PanelHeader: View {
    @Bindable var model: NotchViewModel

    var body: some View {
        HStack {
            Text(Self.dateTitle())
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(PanelStyle.secondary)
            Spacer()
            IconButton(systemImage: model.isPinned ? "pin.fill" : "pin", label: "Pin panel", isOn: model.isPinned) {
                model.isPinned.toggle()
            }
            .accessibilityAddTraits(model.isPinned ? .isSelected : [])
        }
        .padding(.leading, 24)
        .padding(.trailing, 12)
    }

    static func dateTitle(for date: Date = .now) -> String {
        let text = date.formatted(.dateTime.weekday(.wide).day().month(.wide))
        return text.prefix(1).uppercased() + text.dropFirst()
    }
}
