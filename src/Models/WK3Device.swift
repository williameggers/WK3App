import Foundation
import Combine

final class WK3Device: ObservableObject {
    @Published var hostModeActive = false

    private let serial: SerialService
    private var cancellables = Set<AnyCancellable>()

    var lastCommandByte: UInt8?
    var adminOpenSequence = false
    var expectingRevisionCode = false
    var expectingStatusByte = false

    var onDataReceived: ((Data) -> Void)?
    var onStatusUpdate: ((String) -> Void)?
    var onHostModeChanged: ((Bool) -> Void)?

    init(serial: SerialService) {
        self.serial = serial
        serial.onDataReceived = { [weak self] data in
            self?.handleReceivedData(data)
        }
        serial.onError = { [weak self] error in
            self?.onStatusUpdate?("Error: \(error)")
        }
    }

    func connect(port: String, baudRate: Int32) {
        serial.connect(port: port, baudRate: baudRate)
    }

    func disconnect() {
        hostModeActive = false
        onHostModeChanged?(false)
        serial.disconnect()
    }

    func sendBytes(_ bytes: [UInt8]) -> Bool {
        guard serial.isConnected else {
            onStatusUpdate?("Not connected to device")
            return false
        }

        if bytes.count >= 2 && bytes[0] == 0x00 {
            onStatusUpdate?("Tracking Admin command: 0x\(String(bytes[1], radix: 16, uppercase: true))")
        }

        let hexStr = bytes.map { String(format: "%02X", $0) }.joined(separator: " ")
        onStatusUpdate?("Sent: \(hexStr)")

        if let text = String(bytes: bytes, encoding: .ascii), text.allSatisfy(\.isASCII) {
            onStatusUpdate?("    Text: \"\(text)\"")
        }

        return serial.sendBytes(bytes)
    }

    func enterHostMode() {
        adminOpenSequence = true
        expectingRevisionCode = true
        guard sendBytes([0x00, 0x02]) else { return }
        onStatusUpdate?("Sent host mode entry command (Admin:Open)")
        onStatusUpdate?("    Waiting for response...")
    }

    func exitHostMode() {
        guard sendBytes([0x00, 0x03]) else { return }
        hostModeActive = false
        onHostModeChanged?(false)
        onStatusUpdate?("Exited host mode")
    }

    func resetDevice() {
        _ = sendBytes([0x00, 0x01])
        onStatusUpdate?("Reset sent (Admin:Reset)")
    }

    func echoTest() {
        _ = sendBytes([0x00, 0x04])
        _ = sendBytes([0x41])
        onStatusUpdate?("Echo test sent")
    }

    func setWPM(_ wpm: Int) {
        let hex = UInt8(wpm)
        _ = sendBytes([0x02, hex])
        onStatusUpdate?("Set speed to \(wpm) WPM")
    }

    func setKeyCompensation(_ ms: Int) {
        let hex = UInt8(ms)
        _ = sendBytes([0x11, hex])
        onStatusUpdate?("Set key compensation to \(ms) ms")
    }

    func setModeRegister(_ value: UInt8) {
        _ = sendBytes([0x0E, value])
        let binStr = String(value, radix: 2).leftPadded(toLength: 8, withPad: "0")
        onStatusUpdate?("WKMode register: 0x\(String(format: "%02X", value)) (\(binStr))")
    }

    func setPinConfig(_ value: UInt8) {
        _ = sendBytes([0x09, value])
        let binStr = String(value, radix: 2).leftPadded(toLength: 8, withPad: "0")
        onStatusUpdate?("Pin config: 0x\(String(format: "%02X", value)) (\(binStr))")
    }

    func requestStatus() {
        expectingStatusByte = true
        _ = sendBytes([0x15])
        onStatusUpdate?("Status request sent")
    }

    func sendRawHex(_ hexString: String) -> Bool {
        guard let bytes = hexToBytes(hexString) else {
            onStatusUpdate?("Invalid hex string")
            return false
        }
        return sendBytes(bytes)
    }

    func sendText(_ text: String) -> Bool {
        let upper = text.uppercased()
        guard let data = upper.data(using: .ascii) else {
            onStatusUpdate?("Error: Only ASCII characters are allowed")
            return false
        }
        return sendBytes([UInt8](data))
    }

    private func handleReceivedData(_ data: Data) {
        for byte in data {
            let hexVal = String(format: "%02X", byte)

            if (byte & 0xC0) == 0xC0 {
                processStatusByte(byte, hex: hexVal)
            } else if (byte & 0xC0) == 0x80 {
                let potValue = Int(byte & 0x3F)
                onStatusUpdate?("Speed Pot: 0x\(hexVal) (Value: \(potValue)/63)")
                onDataReceived?(Data([byte]))
            } else {
                processEchoBackByte(byte, hex: hexVal)
                onDataReceived?(Data([byte]))
            }
        }
    }

    private func processStatusByte(_ byte: UInt8, hex: String) {
        let busy = (byte & 0x04) != 0
        let breakIn = (byte & 0x02) != 0
        let bufferXoff = (byte & 0x01) != 0

        if byte == 0xC8 {
            onStatusUpdate?("Status Byte: 0x\(hex) - WK3 is ready")
        } else {
            onStatusUpdate?("Status Byte: 0x\(hex) - BUSY: \(busy ? "YES" : "NO"), BREAKIN: \(breakIn ? "YES" : "NO"), XOFF: \(bufferXoff ? "YES" : "NO")")
            if breakIn {
                onStatusUpdate?("    Paddle input detected")
            }
        }

        if expectingStatusByte {
            expectingStatusByte = false
            onStatusUpdate?("    Received status byte in response to status request")
        }
    }

    private func processEchoBackByte(_ byte: UInt8, hex: String) {
        if lastCommandByte == 0x21 {
            let voltage = (26214.0 / Double(byte)) / 100.0
            onStatusUpdate?("VCC Voltage: \(String(format: "%.2f", voltage))V")
            lastCommandByte = nil
            return
        }
        if lastCommandByte == 0x22 {
            onStatusUpdate?("X2MODE register value: 0x\(hex)")
            lastCommandByte = nil
            return
        }
        if lastCommandByte == 0x24 {
            let icType = byte == 0x01 ? "SMT" : "DIP"
            onStatusUpdate?("IC Type: \(icType)")
            lastCommandByte = nil
            return
        }

        if adminOpenSequence && expectingRevisionCode {
            adminOpenSequence = false
            expectingRevisionCode = false
            hostModeActive = true
            onHostModeChanged?(true)
            onStatusUpdate?("Host mode activated with default settings")
            return
        }

        if byte == 0x0E {
            onStatusUpdate?("Mode register set acknowledged")
        } else if byte == 0x09 {
            onStatusUpdate?("Pin config set acknowledged")
        } else if byte == 0x15 {
            onStatusUpdate?("Status request acknowledged")
            expectingStatusByte = true
        } else if byte == 0x03 {
            hostModeActive = false
            onHostModeChanged?(false)
            onStatusUpdate?("Host mode exited successfully")
        }
    }

    private func hexToBytes(_ hex: String) -> [UInt8]? {
        let cleaned = hex.replacingOccurrences(of: " ", with: "")
        guard cleaned.count % 2 == 0,
              cleaned.allSatisfy("0123456789ABCDEFabcdef".contains) else {
            return nil
        }
        var bytes: [UInt8] = []
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            if let byte = UInt8(cleaned[index..<next], radix: 16) {
                bytes.append(byte)
            } else {
                return nil
            }
            index = next
        }
        return bytes
    }
}

private extension String {
    func leftPadded(toLength length: Int, withPad pad: Character) -> String {
        if count >= length { return self }
        return String(repeating: String(pad), count: length - count) + self
    }
}
