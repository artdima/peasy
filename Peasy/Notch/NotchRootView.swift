import SwiftUI

struct NotchRootView: View {
    let model: NotchViewModel

    var body: some View {
        UnevenRoundedRectangle(bottomLeadingRadius: 10, bottomTrailingRadius: 10, style: .continuous)
            .fill(.black)
            .opacity(model.geometry?.hasNotch == false ? 1 : 0)
            .ignoresSafeArea()
    }
}
