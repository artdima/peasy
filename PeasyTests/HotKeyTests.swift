import Carbon.HIToolbox
import Testing
@testable import Peasy

@MainActor
struct HotKeyTests {
    @Test func defaultShortcutRegisters() {
        let hotKey = GlobalHotKey()
        defer { hotKey.unregister() }
        let status = hotKey.register(.default)
        #expect(status == noErr, "RegisterEventHotKey returned \(status)")
        #expect(hotKey.shortcut == .default)
    }

    @Test func defaultShortcutIsControlOptionN() {
        let shortcut = Shortcut.default
        #expect(shortcut.keyCode == UInt32(kVK_ANSI_N))
        #expect(shortcut.carbonModifiers == UInt32(controlKey | optionKey))
        #expect(shortcut.symbols == ["⌃", "⌥", "N"])
    }
}
