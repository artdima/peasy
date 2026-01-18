import SwiftUI

struct NotchRootView: View {
    let model: NotchViewModel

    var body: some View {
        UnevenRoundedRectangle(
            bottomLeadingRadius: model.isExpanded ? 22 : 10,
            bottomTrailingRadius: model.isExpanded ? 22 : 10,
            style: .continuous
        )
        .fill(.black)
        .opacity(isVisible ? 1 : 0)
        .ignoresSafeArea()
    }

    private var isVisible: Bool {
        model.isExpanded || model.geometry?.hasNotch == false
    }
}
