import AppKit
import Carbon

final class KeyboardEmulationService {
    static let shared = KeyboardEmulationService()

    func typeCharacter(_ character: String) {
        let chars = Array(character.utf16)
        var unicodeChars = chars

        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)!
        keyDown.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &unicodeChars)
        keyDown.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false)!
        keyUp.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: &unicodeChars)
        keyUp.post(tap: .cghidEventTap)
    }

    func typeNewline() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: true)!
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: false)!
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    func typeSpace() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: true)!
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 49, keyDown: false)!
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    func pressKey(virtualKey: CGKeyCode, keyDown: Bool) {
        let source = CGEventSource(stateID: .hidSystemState)
        let event = CGEvent(keyboardEventSource: source, virtualKey: virtualKey, keyDown: keyDown)!
        event.post(tap: .cghidEventTap)
    }

    func pressLeftControl(duration: TimeInterval) {
        pressKey(virtualKey: UInt16(kVK_Control), keyDown: true)
        Thread.sleep(forTimeInterval: duration)
        pressKey(virtualKey: UInt16(kVK_Control), keyDown: false)
    }

    func pressRightControl(duration: TimeInterval) {
        pressKey(virtualKey: UInt16(kVK_RightControl), keyDown: true)
        Thread.sleep(forTimeInterval: duration)
        pressKey(virtualKey: UInt16(kVK_RightControl), keyDown: false)
    }

    func typeMorseForCharacter(
        _ character: Character,
        keyDuration: TimeInterval,
        keyDelay: TimeInterval,
        letterSpacing: TimeInterval,
        completion: @escaping (String) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let pattern = MorseCode.pattern(for: character) else {
                DispatchQueue.main.async { completion("") }
                return
            }

            var controlSequence: [String] = []
            for (i, symbol) in pattern.enumerated() {
                if symbol == "." {
                    self.pressLeftControl(duration: keyDuration)
                    controlSequence.append("L")
                } else {
                    self.pressRightControl(duration: keyDuration)
                    controlSequence.append("R")
                }
                if i < pattern.count - 1 {
                    Thread.sleep(forTimeInterval: keyDelay)
                }
            }
            Thread.sleep(forTimeInterval: letterSpacing)

            let result = "MorseInvaders: '\(character.uppercased())' → \(controlSequence.joined(separator: " "))"
            DispatchQueue.main.async { completion(result) }
        }
    }
}
