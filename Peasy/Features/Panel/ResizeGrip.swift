import AppKit
import SwiftUI

/// The panel hangs from the status item by its top right corner, so only the
/// left and bottom edges move.
enum ResizeEdge: CaseIterable {
    case left
    case bottom
    case bottomLeft

    static let thickness: CGFloat = 5
    static let cornerSize: CGFloat = 18

    func size(from size: CGSize, dragFrom start: CGPoint, to mouse: CGPoint) -> CGSize {
        CGSize(
            width: self == .bottom ? size.width : size.width + start.x - mouse.x,
            height: self == .left ? size.height : size.height + start.y - mouse.y
        )
    }

    var cursor: NSCursor {
        if #available(macOS 15, *) {
            switch self {
            case .left: return NSCursor.frameResize(position: .left, directions: .all)
            case .bottom: return NSCursor.frameResize(position: .bottom, directions: .all)
            case .bottomLeft: return NSCursor.frameResize(position: .bottomLeft, directions: .all)
            }
        }
        switch self {
        case .left: return .resizeLeftRight
        case .bottom: return .resizeUpDown
        case .bottomLeft: return .crosshair
        }
    }
}

struct ResizeGrip: View {
    let model: PanelViewModel
    var edge: ResizeEdge = .bottomLeft

    @State private var dragStart: (mouse: CGPoint, size: CGSize)?
    @State private var isHovered = false

    var body: some View {
        Color.clear
            .frame(
                width: edge == .bottom ? nil : edge == .left ? ResizeEdge.thickness : ResizeEdge.cornerSize,
                height: edge == .left ? nil : edge == .bottom ? ResizeEdge.thickness : ResizeEdge.cornerSize
            )
            .contentShape(Rectangle())
            .onHover { hovering in
                isHovered = hovering
                if hovering {
                    edge.cursor.push()
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
                        model.onResize(edge.size(from: start.size, dragFrom: start.mouse, to: mouse), false)
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
}
