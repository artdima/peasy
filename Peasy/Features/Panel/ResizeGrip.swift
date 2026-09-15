import AppKit
import SwiftUI

/// Invisible corner handle: dragging it resizes the panel. The panel's right edge
/// is anchored under the status item, so it grows to the left.
struct ResizeGrip: View {
    let model: PanelViewModel

    @State private var dragStart: (mouse: CGPoint, size: CGSize)?
    @State private var isHovered = false

    var body: some View {
        Color.clear
            .frame(width: 18, height: 18)
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    Self.cursor.push()
                } else if dragStart == nil {
                    NSCursor.pop()
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .global)
                    .onChanged { _ in
                        let mouse = NSEvent.mouseLocation
                        let start = dragStart ?? (mouse, model.panelSize)
                        dragStart = start
                        model.onResize(
                            CGSize(
                                width: start.size.width + (start.mouse.x - mouse.x),
                                height: start.size.height + (start.mouse.y - mouse.y)
                            ),
                            false
                        )
                    }
                    .onEnded { _ in
                        dragStart = nil
                        model.onResize(model.panelSize, true)
                        if !isHovered {
                            NSCursor.pop()
                        }
                    }
            )
            .accessibilityLabel("Resize panel")
    }

    private static var cursor: NSCursor {
        if #available(macOS 15, *) {
            NSCursor.frameResize(position: .bottomLeft, directions: .all)
        } else {
            NSCursor.crosshair
        }
    }
}
