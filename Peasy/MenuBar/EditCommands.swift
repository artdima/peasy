import AppKit

enum EditCommands {
    static func action(for event: NSEvent) -> Selector? {
        let modifiers = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.numericPad, .function, .capsLock])
        let characters = event.charactersIgnoringModifiers?.lowercased() ?? ""
        return action(modifiers: modifiers, characters: characters)
    }

    static func action(modifiers: NSEvent.ModifierFlags, characters: String) -> Selector? {
        switch (modifiers, characters) {
        case (.command, "x"): #selector(NSText.cut(_:))
        case (.command, "c"): #selector(NSText.copy(_:))
        case (.command, "v"): #selector(NSText.paste(_:))
        case (.command, "a"): #selector(NSText.selectAll(_:))
        case (.command, "z"): Selector(("undo:"))
        case ([.command, .shift], "z"): Selector(("redo:"))
        default: nil
        }
    }
}
