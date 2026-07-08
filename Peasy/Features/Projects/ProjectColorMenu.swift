import AppKit
import SwiftUI

struct ProjectColorMenu: View {
    let project: Project
    let store: TaskStore

    var body: some View {
        Menu("Color") {
            ForEach(ProjectPalette.colors, id: \.self) { hex in
                Toggle(isOn: Binding(
                    get: { project.colorHex == hex },
                    set: { _ in store.setColor(project, to: hex) }
                )) {
                    Label {
                        Text(ProjectPalette.name(of: hex))
                    } icon: {
                        Image(nsImage: Self.swatch(hex: hex))
                    }
                }
            }
        }
    }

    private static func swatch(hex: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 12, height: 12), flipped: false) { rect in
            NSColor(Color(hex: hex)).setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
        image.isTemplate = false
        return image
    }
}
