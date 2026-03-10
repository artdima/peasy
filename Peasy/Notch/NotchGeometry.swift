import AppKit

struct NotchGeometry: Equatable {
    static let virtualNotchWidth: CGFloat = 180
    static let minimumMenuBarHeight: CGFloat = 24

    let screenFrame: CGRect
    let notchRect: CGRect
    let hasNotch: Bool

    init(
        screenFrame: CGRect,
        topInset: CGFloat,
        leftAreaWidth: CGFloat?,
        rightAreaWidth: CGFloat?,
        menuBarHeight: CGFloat
    ) {
        self.screenFrame = screenFrame
        if topInset > 0, let leftAreaWidth, let rightAreaWidth {
            let width = screenFrame.width - leftAreaWidth - rightAreaWidth
            if width > 0 {
                notchRect = CGRect(
                    x: screenFrame.minX + leftAreaWidth,
                    y: screenFrame.maxY - topInset,
                    width: width,
                    height: topInset
                )
                hasNotch = true
                return
            }
        }
        let height = max(menuBarHeight, Self.minimumMenuBarHeight)
        notchRect = CGRect(
            x: screenFrame.midX - Self.virtualNotchWidth / 2,
            y: screenFrame.maxY - height,
            width: Self.virtualNotchWidth,
            height: height
        )
        hasNotch = false
    }
}

extension NotchGeometry {
    init(screen: NSScreen) {
        self.init(
            screenFrame: screen.frame,
            topInset: screen.safeAreaInsets.top,
            leftAreaWidth: screen.auxiliaryTopLeftArea?.width,
            rightAreaWidth: screen.auxiliaryTopRightArea?.width,
            menuBarHeight: screen.frame.maxY - screen.visibleFrame.maxY
        )
    }
}
