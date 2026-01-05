import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Peasy")
                .font(.largeTitle.weight(.semibold))
            Text("Little tasks, big growth.")
                .foregroundStyle(.secondary)
        }
        .frame(width: 360, height: 200)
    }
}

#Preview {
    SettingsView()
}
