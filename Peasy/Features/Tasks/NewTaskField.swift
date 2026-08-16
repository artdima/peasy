import SwiftUI

struct NewTaskField: View {
    @Bindable var model: NotchViewModel
    let placeholder: LocalizedStringKey
    let onSubmit: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Glyph(kind: .plus, size: 12)
                .foregroundStyle(PanelStyle.tertiary)
                .frame(width: 30)
                .offset(y: 0.5)
            TextField(placeholder, text: $model.draft)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .focused($isFocused)
                .offset(y: 1)
                .onSubmit {
                    onSubmit(model.draft)
                    model.draft = ""
                    isFocused = true
                }
            if !model.draft.trimmingCharacters(in: .whitespaces).isEmpty {
                Text(verbatim: "↩")
                    .font(.system(size: 11))
                    .foregroundStyle(PanelStyle.secondary)
                    .padding(.horizontal, 6)
                    .frame(height: 18)
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(.white.opacity(0.18)))
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .frame(height: 42)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(PanelStyle.separator)
                .frame(height: 1)
        }
        .onChange(of: model.newTaskFocusRequest) {
            isFocused = true
        }
    }
}
