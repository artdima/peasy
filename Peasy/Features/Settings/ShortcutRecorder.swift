import AppKit
import Carbon.HIToolbox
import SwiftUI

extension Notification.Name {
    static let shortcutRecordingChanged = Notification.Name("PeasyShortcutRecordingChanged")
}

struct ShortcutRecorder: View {
    @State private var shortcut = Shortcut.current
    @State private var isRecording = false
    @State private var isHovered = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Group {
                if isRecording {
                    Text("Press a shortcut…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(PanelStyle.green)
                        .padding(.horizontal, 10)
                } else {
                    HStack(spacing: 4) {
                        ForEach(shortcut.symbols, id: \.self) { symbol in
                            Text(verbatim: symbol)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(PanelStyle.primary)
                                .padding(.horizontal, 6)
                                .frame(minWidth: 22, minHeight: 22)
                                .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(.white.opacity(0.06))
                                        .frame(height: 1)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            .frame(height: 30)
            .background(.white.opacity(isHovered && !isRecording ? 0.06 : 0), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(PanelStyle.green, lineWidth: isRecording ? 1.5 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .onDisappear(perform: stop)
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            stop()
        }
        .accessibilityLabel(isRecording ? Text("Press a new shortcut") : Text("Quick new task shortcut: \(shortcut.symbols.joined(separator: " "))"))
    }

    private func toggle() {
        isRecording ? stop() : start()
    }

    private func start() {
        isRecording = true
        NotificationCenter.default.post(name: .shortcutRecordingChanged, object: true)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if Int(event.keyCode) == kVK_Escape {
                stop()
            } else if let recorded = Shortcut(event: event) {
                recorded.save()
                shortcut = recorded
                stop()
            }
            return nil
        }
    }

    private func stop() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        guard isRecording else { return }
        isRecording = false
        NotificationCenter.default.post(name: .shortcutRecordingChanged, object: false)
    }
}
