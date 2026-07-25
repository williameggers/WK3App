import SwiftUI

struct ContentView: View {
    @ObservedObject var state: AppState
    @ObservedObject var device: WK3Device
    @ObservedObject var serial: SerialService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                InfoBanner()

                ConnectionView(state: state, device: device, serial: serial)

                Divider()

                KeyerSettingsView(state: state, device: device)

                Divider()

                ToolsView(state: state)

                Divider()

                ASCIIMonitorView(state: state)
            }
        }
        .frame(minWidth: 700, minHeight: 500)
        .sheet(isPresented: $state.showAdvancedSettings) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Advanced Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Divider()
                PinCFGView(state: state, device: device)
                Divider()
                WKModeView(state: state, device: device)
                Spacer()
                HStack {
                    Spacer()
                    Button("Close") {
                        state.showAdvancedSettings = false
                    }
                    .controlSize(.large)
                }
            }
            .padding()
            .frame(minWidth: 500, minHeight: 300)
        }
        .sheet(isPresented: $state.showAbout) {
            AboutView()
        }
        .onAppear {
            device.onStatusUpdate = { message in
                state.addLog(message, type: .info)
            }
            device.onHostModeChanged = { active in
                state.connectionStatus = active ? .hostMode : .connected
            }
            device.onDataReceived = { data in
                for byte in data {
                    if byte == 0x0D || byte == 0x0A {
                        state.appendToMonitor("\n")
                        if state.keyboardEmulationActive {
                            KeyboardEmulationService.shared.typeNewline()
                        }
                    } else if byte == 0x20 {
                        state.appendToMonitor(" ")
                        if state.keyboardEmulationActive {
                            KeyboardEmulationService.shared.typeSpace()
                        }
                    } else if byte >= 0x20 && byte <= 0x7E {
                        let charStr = String(Character(UnicodeScalar(byte)))
                        state.appendToMonitor(charStr)
                        if state.keyboardEmulationActive {
                            KeyboardEmulationService.shared.typeCharacter(charStr)
                            state.emulationStatus = "Last key: \(charStr)"
                        } else if state.morseInvadersActive {
                            let char = Character(charStr)
                            KeyboardEmulationService.shared.typeMorseForCharacter(
                                char,
                                keyDuration: state.keyDuration / 1000.0,
                                keyDelay: state.keyDelay / 1000.0,
                                letterSpacing: state.letterSpacing / 1000.0
                            ) { status in
                                if !status.isEmpty {
                                    state.emulationStatus = status
                                }
                            }
                        }
                    }
                }
            }
            checkAccessibility()
            startPortRefresh()
        }
        .alert("Accessibility Permission Required", isPresented: $state.showAccessibilityAlert) {
            Button("Open System Settings") {
                AccessibilityService.shared.openAccessibilitySettings()
            }
            Button("Continue Without", role: .cancel) { }
        } message: {
            Text("WK3App needs Accessibility access for keyboard emulation and MorseInvaders mode.\n\nPlease enable in System Settings > Privacy & Security > Accessibility.")
        }
    }

    private func checkAccessibility() {
        state.accessibilityGranted = AccessibilityService.shared.requestAccessibility()
        if !state.accessibilityGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                state.showAccessibilityAlert = true
            }
        }

        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            let granted = AccessibilityService.shared.isTrusted
            state.accessibilityGranted = granted
            if granted {
                state.showAccessibilityAlert = false
            }
        }
    }

    private func startPortRefresh() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            serial.refreshPorts()
        }
        serial.refreshPorts()
    }
}

struct InfoBanner: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Info").font(.headline)
            Text("Connect a WK3 device, click 'Connect to Device', select COM Port. Open Host Mode to change settings and begin paddle echo.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.accentColor.opacity(0.05))
    }
}
