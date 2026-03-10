import SwiftUI

struct SettingsView: View {
    @AppStorage(DisplayPreference.storageKey) private var display = DisplayPreference.builtIn

    var body: some View {
        Form {
            Picker("Show on", selection: $display) {
                ForEach(DisplayPreference.allCases) { preference in
                    Text(preference.title).tag(preference)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

#Preview {
    SettingsView()
}
