import SwiftUI

struct NotchRootView: View {
    let model: NotchViewModel
    let actions: NotchActions

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
                NotchContentView(model: model)
                    .frame(width: model.contentSize.width, height: model.contentSize.height, alignment: .top)
                    .padding(.top, model.collapsedSize.height)
                    .transition(.opacity.animation(.easeOut(duration: 0.18).delay(0.08)))
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
        .animation(.smooth(duration: 0.25), value: model.contentSize.height)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Settings…", action: actions.openSettings)
            Divider()
            Button("Quit Peasy", action: actions.quit)
        }
        .opacity(isVisible ? 1 : 0)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .environment(\.colorScheme, .dark)
        .ignoresSafeArea()
    }

    private var isVisible: Bool {
        model.isExpanded || model.geometry?.hasNotch == false
    }
}
