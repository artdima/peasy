import AppKit
import Carbon.HIToolbox

struct Shortcut: Equatable {
    static let storageKey = "quickAddShortcut"
    static let `default` = Shortcut(keyCode: UInt32(kVK_ANSI_N), modifiers: [.control, .option], key: "N")

    var keyCode: UInt32
    var modifiers: NSEvent.ModifierFlags
    var key: String

    static var current: Shortcut {
        guard let stored = UserDefaults.standard.dictionary(forKey: storageKey),
              let keyCode = stored["keyCode"] as? Int,
              let modifiers = stored["modifiers"] as? UInt,
              let key = stored["key"] as? String
        else { return .default }
        return Shortcut(keyCode: UInt32(keyCode), modifiers: NSEvent.ModifierFlags(rawValue: modifiers), key: key)
    }

    init(keyCode: UInt32, modifiers: NSEvent.ModifierFlags, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection([.control, .option, .shift, .command])
        self.key = key
    }

    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.control, .option, .shift, .command])
        guard !modifiers.subtracting(.shift).isEmpty else { return nil }
        let key: String
        switch Int(event.keyCode) {
        case kVK_Space: key = "Space"
        case kVK_Return: key = "↩"
        default: key = (event.charactersIgnoringModifiers ?? "").uppercased()
        }
        guard !key.isEmpty else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: modifiers, key: key)
    }

    func save() {
        UserDefaults.standard.set(
            ["keyCode": Int(keyCode), "modifiers": modifiers.rawValue, "key": key],
            forKey: Self.storageKey
        )
    }

    var symbols: [String] {
        var symbols: [String] = []
        if modifiers.contains(.control) { symbols.append("⌃") }
        if modifiers.contains(.option) { symbols.append("⌥") }
        if modifiers.contains(.shift) { symbols.append("⇧") }
        if modifiers.contains(.command) { symbols.append("⌘") }
        return symbols + [key]
    }

    var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }
}

@MainActor
final class GlobalHotKey {
    var action: () -> Void = {}
    private(set) var shortcut: Shortcut?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    @discardableResult
    func register(_ shortcut: Shortcut) -> OSStatus {
        unregister()
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: OSType(0x5045_4153), id: 1)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.carbonModifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        self.shortcut = status == noErr ? shortcut : nil
        return status
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
        shortcut = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return noErr }
            let hotKey = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                hotKey.action()
            }
            return noErr
        }, 1, &spec, context, &handlerRef)
    }
}
