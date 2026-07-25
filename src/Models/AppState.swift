import Foundation
import SwiftUI
import AppKit

enum ConnectionStatus: Equatable {
    case disconnected
    case connected
    case hostMode
}

enum KeyerMode: Int, CaseIterable, Identifiable {
    case iambicB = 0
    case iambicA = 1
    case ultimatic = 2
    case bug = 3

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .iambicB: return "Iambic B"
        case .iambicA: return "Iambic A"
        case .ultimatic: return "Ultimatic"
        case .bug: return "Bug Mode"
        }
    }
}

enum UltimaticPriority: Int, CaseIterable, Identifiable {
    case normal = 0
    case dahPriority = 1
    case ditPriority = 2

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .normal: return "Normal"
        case .dahPriority: return "Dah Priority"
        case .ditPriority: return "Dit Priority"
        }
    }
}

enum Hangtime: Int, CaseIterable, Identifiable {
    case ws1dit1 = 0
    case ws1dit2 = 1
    case ws1dit4 = 2
    case ws1dit8 = 3

    var id: Int { rawValue }

    var name: String {
        switch self {
        case .ws1dit1: return "1 wordspace + 1 dit"
        case .ws1dit2: return "1 wordspace + 2 dits"
        case .ws1dit4: return "1 wordspace + 4 dits"
        case .ws1dit8: return "1 wordspace + 8 dits"
        }
    }
}

struct LogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let message: String
    let type: LogEntryType

    enum LogEntryType {
        case info, sent, received, error, connected, disconnected

        var color: Color {
            switch self {
            case .info: return .secondary
            case .sent: return .blue
            case .received: return .green
            case .error: return .red
            case .connected: return .green
            case .disconnected: return .orange
            }
        }
    }

    init(message: String, type: LogEntryType = .info) {
        self.timestamp = Date()
        self.message = message
        self.type = type
    }
}

@MainActor
final class AppState: ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var selectedPort: String = ""
    @Published var selectedBaud: Int = 1200
    @Published var asciiMonitorText: String = ""
    @Published var logEntries: [LogEntry] = []
    @Published var sendText: String = ""
    @Published var charCount: Int = 0

    // WKMode register bits
    @Published var paddleWatchdogDisabled = false
    @Published var paddleEchoEnabled = true
    @Published var keyerMode: KeyerMode = .iambicB
    @Published var paddleSwapped = false
    @Published var serialEchoEnabled = false
    @Published var autospaceEnabled = false
    @Published var contestSpacingEnabled = false

    // PinCFG register bits
    @Published var ultimaticPriority: UltimaticPriority = .normal
    @Published var hangtimeSetting: Hangtime = .ws1dit1
    @Published var keyout1Enabled = false
    @Published var keyout2Enabled = true
    @Published var sidetoneEnabled = true
    @Published var pttEnabled = false

    // WPM and key compensation
    @Published var currentWPM: Int = 20
    @Published var currentKeyComp: Int = 25

    // Emulation
    @Published var keyboardEmulationActive = false
    @Published var morseInvadersActive = false
    @Published var capsLockEnabled = true
    @Published var emulationStatus: String = ""

    // MorseInvaders timing
    @Published var keyDuration: Double = 100
    @Published var keyDelay: Double = 150
    @Published var letterSpacing: Double = 400

    // Debug
    @Published var debugWindowOpen = false
    @Published var showAdvancedSettings = false
    @Published var showAbout = false
    @Published var showToolSettings = false
    @Published var sendWindowOpen = false
    @Published var commandInput: String = ""
    var debugWindow: NSWindow?
    var sendWindow: NSWindow?
    weak var device: WK3Device?

    // Permission
    @Published var showAccessibilityAlert = false
    @Published var accessibilityGranted = false

    // Internal state
    var lastCommandByte: UInt8?
    var adminOpenSequence = false
    var expectingRevisionCode = false
    var expectingStatusByte = false

    // Computed mode register
    var modeRegister: UInt8 {
        var reg: UInt8 = 0
        if paddleWatchdogDisabled { reg |= 0x80 }
        if paddleEchoEnabled { reg |= 0x40 }
        reg |= UInt8(keyerMode.rawValue & 0x03) << 4
        if paddleSwapped { reg |= 0x08 }
        if serialEchoEnabled { reg |= 0x04 }
        if autospaceEnabled { reg |= 0x02 }
        if contestSpacingEnabled { reg |= 0x01 }
        return reg
    }

    // Computed pin config
    var pinConfig: UInt8 {
        var cfg: UInt8 = 0
        cfg |= UInt8(ultimaticPriority.rawValue & 0x03) << 6
        cfg |= UInt8(hangtimeSetting.rawValue & 0x03) << 4
        if keyout1Enabled { cfg |= 0x08 }
        if keyout2Enabled { cfg |= 0x04 }
        if sidetoneEnabled { cfg |= 0x02 }
        if pttEnabled { cfg |= 0x01 }
        return cfg
    }

    func parseModeRegister(_ value: UInt8) {
        paddleWatchdogDisabled = (value & 0x80) != 0
        paddleEchoEnabled = (value & 0x40) != 0
        keyerMode = KeyerMode(rawValue: Int((value >> 4) & 0x03)) ?? .iambicA
        paddleSwapped = (value & 0x08) != 0
        serialEchoEnabled = (value & 0x04) != 0
        autospaceEnabled = (value & 0x02) != 0
        contestSpacingEnabled = (value & 0x01) != 0
    }

    func parsePinConfig(_ value: UInt8) {
        ultimaticPriority = UltimaticPriority(rawValue: Int((value >> 6) & 0x03)) ?? .normal
        hangtimeSetting = Hangtime(rawValue: Int((value >> 4) & 0x03)) ?? .ws1dit1
        keyout1Enabled = (value & 0x08) != 0
        keyout2Enabled = (value & 0x04) != 0
        sidetoneEnabled = (value & 0x02) != 0
        pttEnabled = (value & 0x01) != 0
    }

    func addLog(_ message: String, type: LogEntry.LogEntryType = .info) {
        logEntries.append(LogEntry(message: message, type: type))
    }

    func appendToMonitor(_ text: String) {
        asciiMonitorText += text
    }

    func clearMonitor() {
        asciiMonitorText = ""
    }

    func clearLog() {
        logEntries.removeAll()
        addLog("Log cleared...")
    }

    func updateCharCount() {
        charCount = sendText.count
    }

    func openDebugWindow() {
        if let existing = debugWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let device = device else { return }

        let hostingView = NSHostingView(rootView: DebugView(state: self, device: device))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Debug"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.debugWindow = nil
            self?.debugWindowOpen = false
        }

        debugWindow = window
        debugWindowOpen = true
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeDebugWindow() {
        debugWindow?.close()
        debugWindow = nil
        debugWindowOpen = false
    }

    func openSendWindow() {
        if let existing = sendWindow {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        guard let device = device else { return }

        let hostingView = NSHostingView(rootView: SendTextView(state: self, device: device))

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 250),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Send Text"
        window.contentView = hostingView
        window.center()
        window.isReleasedWhenClosed = false

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.sendWindow = nil
            self?.sendWindowOpen = false
        }

        sendWindow = window
        sendWindowOpen = true
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func closeSendWindow() {
        sendWindow?.close()
        sendWindow = nil
        sendWindowOpen = false
    }
}
