import CoreGraphics

/// The floating panel under the status item, in points.
enum PanelGeometry {
    static let cornerRadius: CGFloat = 20
    /// Space between the menu bar's bottom edge and the panel.
    static let gap: CGFloat = 6
    /// How far the panel's right edge reaches past the status item.
    static let overhang: CGFloat = 52
    static let headerHeight: CGFloat = 46
    static let screenMargin: CGFloat = 8
}

/// Where the panel window goes for a status item.
struct PanelPlacement: Equatable {
    /// Screen coordinates, y up.
    var frame: CGRect

    /// `item` is the status item's frame in screen coordinates with its bottom on the
    /// menu bar's bottom edge; `screen` the frame of the display it is on. The right
    /// edge is anchored to the item, so resizing from the left corner tracks the pointer;
    /// near a screen edge the panel slides inward.
    init(item: CGRect, screen: CGRect, panelSize: CGSize) {
        let margin = PanelGeometry.screenMargin
        var maxX = min(item.maxX + PanelGeometry.overhang, screen.maxX - margin)
        if maxX - panelSize.width < screen.minX + margin {
            maxX = min(screen.minX + margin + panelSize.width, screen.maxX - margin)
        }
        let top = item.minY - PanelGeometry.gap
        frame = CGRect(x: maxX - panelSize.width, y: top - panelSize.height, width: panelSize.width, height: panelSize.height)
    }
}
