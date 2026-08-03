import SwiftUI

struct PanelHeader: View {
    @Bindable var model: NotchViewModel
    let focusTask: TaskItem?
    let growth: CGFloat
    let onOpenSettings: () -> Void
    let onGoToFocus: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            if model.celebration != nil {
                FocusBand(mood: .done, growth: growth, text: Text("Done"), action: {})
            } else if focusTask != nil {
                FocusBand(mood: .focus, growth: growth, text: Text(Self.dateTitle()), action: onGoToFocus)
            } else {
                Text(Self.dateTitle())
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(PanelStyle.secondary)
            }
            Spacer()
            IconButton(label: "Settings") {
                onOpenSettings()
            } icon: {
                Glyph(kind: .gear, size: 14)
            }
            IconButton(label: "Pin panel", isOn: model.isPinned) {
                model.isPinned.toggle()
            } icon: {
                Glyph(kind: .pin, size: 14, filled: model.isPinned)
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

struct FocusBand: View {
    let mood: BuddyView.Mood
    let growth: CGFloat
    let text: Text
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                BuddyView(mood: mood, growth: growth)
                text
            }
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(isHovered ? PanelStyle.primary : PanelStyle.secondary)
            .padding(.leading, 6)
            .padding(.trailing, 10)
            .frame(height: 30)
            .background(.white.opacity(isHovered ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.leading, -8)
    }
}
