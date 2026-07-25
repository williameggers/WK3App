import SwiftUI

struct PermissionAlerts {
    static func accessibilityAlert() -> Alert {
        Alert(
            title: Text("Accessibility Permission Required"),
            message: Text("WK3App needs Accessibility access for keyboard emulation and MorseInvaders mode.\n\nPlease enable in System Settings > Privacy & Security > Accessibility."),
            primaryButton: .default(Text("Open System Settings")) {
                AccessibilityService.shared.openAccessibilitySettings()
            },
            secondaryButton: .cancel(Text("Continue Without"))
        )
    }
}
