import SwiftUI

struct NewTaskField: View {
    @Bindable var model: NotchViewModel
    let onSubmit: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            TextField("New task", text: $model.draft)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .onSubmit {
                    onSubmit(model.draft)
                    model.draft = ""
                    isFocused = true
                }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .onAppear {
            isFocused = true
        }
    }
}
