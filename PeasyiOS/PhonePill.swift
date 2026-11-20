import SwiftUI

struct PhonePill<Icon: View>: View {
    let title: Text
    var count = 0
    let isSelected: Bool
    let action: () -> Void
    @ViewBuilder let icon: () -> Icon

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                icon()
                title
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(isSelected ? PanelStyle.selectedPrimary : PanelStyle.primary)
                    .lineLimit(1)
                if count > 0 {
                    Text(count, format: .number)
                        .font(.footnote)
                        .monospacedDigit()
                        .foregroundStyle(isSelected ? PanelStyle.selectedTertiary : PanelStyle.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .frame(minHeight: 34)
            .background(isSelected ? PanelStyle.pillSelection : PhoneStyle.pill, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
