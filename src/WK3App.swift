import SwiftUI

@main
struct WK3App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @StateObject private var serial: SerialService
    @StateObject private var device: WK3Device

    init() {
        let serialService = SerialService()
        _serial = StateObject(wrappedValue: serialService)
        _device = StateObject(wrappedValue: WK3Device(serial: serialService))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(state: state, device: device, serial: serial)
                .onAppear {
                    state.device = device
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    serial.disconnect()
                }
        }
        .handlesExternalEvents(matching: [])
        .commands {
            CommandGroup(replacing: .newItem) {
                Button {
                    guard !state.selectedPort.isEmpty else { return }
                    device.connect(port: state.selectedPort, baudRate: Int32(state.selectedBaud))
                    state.connectionStatus = .connected
                    state.addLog("Connected to \(state.selectedPort) at \(state.selectedBaud) baud", type: .connected)
                    state.appendToMonitor("Connected to \(state.selectedPort) at \(state.selectedBaud) baud\n")
                } label: {
                    Label("Connect to Device", systemImage: "cable.connector")
                }
                .keyboardShortcut("c", modifiers: .command)
                .disabled(state.connectionStatus != .disconnected || state.selectedPort.isEmpty)

                Button {
                    state.connectionStatus = .disconnected
                } label: {
                    Label("Disconnect", systemImage: "cable.connector.slash")
                }
                .keyboardShortcut("d", modifiers: .command)
                .disabled(state.connectionStatus == .disconnected)
            }

            CommandGroup(replacing: .appInfo) {
                Button("About WK3App") {
                    state.showAbout = true
                }
            }

            CommandGroup(after: .toolbar) {
                Button {
                    state.openDebugWindow()
                } label: {
                    Label("Debug", systemImage: "ladybug")
                }
                .keyboardShortcut("d", modifiers: [.command, .option])
                .disabled(state.debugWindowOpen)

                Button {
                    state.openSendWindow()
                } label: {
                    Label("Send Text", systemImage: "paperplane")
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
                .disabled(state.sendWindowOpen)

                Toggle(isOn: $state.showAdvancedSettings) {
                    Label("Advanced Settings", systemImage: "gearshape.2")
                }
                .keyboardShortcut("a", modifiers: [.command, .shift])
            }

            CommandMenu("Tools") {
                Toggle(isOn: $state.keyboardEmulationActive) {
                    Label("Keyboard Emulation", systemImage: "keyboard")
                }
                .keyboardShortcut("k", modifiers: .command)

                Toggle(isOn: $state.morseInvadersActive) {
                    Label("Morse Invaders", systemImage: "dot.radiowaves.left.and.right")
                }
                .keyboardShortcut("m", modifiers: .command)
            }
        }
        .defaultSize(width: 700, height: 800)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        false
    }
}
