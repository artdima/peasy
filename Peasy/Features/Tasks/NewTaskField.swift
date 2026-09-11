import SwiftUI

struct NewTaskField: View {
    @Bindable var model: NotchViewModel
    let placeholder: LocalizedStringKey
    let onSubmit: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 14) {
            Glyph(kind: .plus, size: 14)
                .foregroundStyle(PanelStyle.tertiary)
                .frame(width: 30)
            TextField(text: $model.draft, prompt: Text(verbatim: "")) {
                Text(placeholder)
            }
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($isFocused)
                .overlay(alignment: .leading) {
                    if model.draft.isEmpty {
                        Text(placeholder)
                            .font(.system(size: 16))
                            .foregroundStyle(PanelStyle.tertiary)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
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
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(PanelStyle.keyBorder))
                    .accessibilityHidden(true)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 10)
        .frame(height: 46)
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
