import SwiftUI

struct FirstProjectView: View {
    let onCreate: (String) -> Void

    @State private var name = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start with a project")
                .font(.headline)
            Text("Projects keep related tasks together.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            TextField("Project name", text: $name)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                .onSubmit {
                    onCreate(name)
                    name = ""
                }
        }
        .onAppear {
            isFocused = true
        }
    }
}
