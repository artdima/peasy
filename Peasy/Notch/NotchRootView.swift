import SwiftUI

struct NotchRootView: View {
    let model: NotchViewModel

    var body: some View {
        let expanded = model.isExpanded
        let size = expanded ? model.expandedSize : model.collapsedSize
        ZStack(alignment: .top) {
            NotchShape(
                topRadius: expanded ? NotchViewModel.earRadius : 0,
                bottomRadius: expanded ? NotchViewModel.expandedCornerRadius : NotchViewModel.collapsedCornerRadius
            )
            .fill(.black)

            if expanded {
                NotchContentView()
                    .frame(width: model.contentSize.width, height: model.contentSize.height)
                    .padding(.top, model.collapsedSize.height)
                    .transition(.opacity.animation(.easeOut(duration: 0.18).delay(0.08)))
            }
        }
        .frame(width: size.width, height: size.height)
        .opacity(isVisible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
        .ignoresSafeArea()
    }

    private var isVisible: Bool {
        model.isExpanded || model.geometry?.hasNotch == false
    }
}

struct NotchContentView: View {
    var body: some View {
        VStack(spacing: 4) {
            Text("Peasy")
                .font(.headline)
            Text("Little tasks, big growth.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
