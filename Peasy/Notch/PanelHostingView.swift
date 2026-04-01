import AppKit
import SwiftUI

final class PanelHostingView<Content: View>: NSHostingView<Content> {
    override var safeAreaInsets: NSEdgeInsets {
        NSEdgeInsets()
    }
}
