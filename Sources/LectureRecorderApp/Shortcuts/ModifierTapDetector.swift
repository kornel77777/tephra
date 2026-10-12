import AppKit

enum ShortcutModifier: String, CaseIterable, Identifiable {
    case control, option, shift, command

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .control: return "⌃"
        case .option: return "⌥"
        case .shift: return "⇧"
        case .command: return "⌘"
        }
    }

    var name: String {
        switch self {
        case .control: return "Control"
        case .option: return "Option"
        case .shift: return "Shift"
        case .command: return "Command"
        }
    }

    var flag: NSEvent.ModifierFlags {
        switch self {
        case .control: return .control
        case .option: return .option
        case .shift: return .shift
        case .command: return .command
        }
    }

    init?(keyCode: UInt16) {
        switch keyCode {
        case 59, 62: self = .control
        case 58, 61: self = .option
        case 56, 60: self = .shift
        case 55, 54: self = .command
        default: return nil
        }
    }
}

/// Spots "double-tap a modifier key": press and release the key alone, twice in
/// quick succession. Any other key press in between cancels it, so ordinary
/// typing and shortcuts like ⌘C never trigger anything.
struct ModifierTapDetector {
    var maxTapDuration: TimeInterval = 0.30
    var maxGapBetweenTaps: TimeInterval = 0.40

    private static let allModifiers: NSEvent.ModifierFlags = [.control, .option, .shift, .command, .function]

    private var pressed: (modifier: ShortcutModifier, time: TimeInterval)?
    private var lastTap: (modifier: ShortcutModifier, time: TimeInterval)?

    /// Feed every `flagsChanged` event. Returns the modifier when a double-tap completes.
    mutating func flagsChanged(keyCode: UInt16, flags: NSEvent.ModifierFlags, time: TimeInterval) -> ShortcutModifier? {
        guard let modifier = ShortcutModifier(keyCode: keyCode) else {
            cancel()
            return nil
        }

        let held = flags.intersection(Self.allModifiers)

        if held == modifier.flag {
            // Pressed on its own.
            pressed = (modifier, time)
            return nil
        }

        if held.isEmpty, let down = pressed, down.modifier == modifier, time - down.time <= maxTapDuration {
            pressed = nil
            if let previous = lastTap, previous.modifier == modifier, time - previous.time <= maxGapBetweenTaps {
                lastTap = nil
                return modifier
            }
            lastTap = (modifier, time)
            return nil
        }

        // Combined with another modifier, held too long, or something else odd.
        cancel()
        return nil
    }

    /// Call for any regular key press — it means the modifier was part of typing.
    mutating func keyPressed() {
        cancel()
    }

    private mutating func cancel() {
        pressed = nil
        lastTap = nil
    }
}
