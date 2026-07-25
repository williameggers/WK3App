import SwiftUI

struct ConnectionView: View {
    @ObservedObject var state: AppState
    @ObservedObject var device: WK3Device
    @ObservedObject var serial: SerialService

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Connection").font(.headline)
                Spacer()
                Button(state.connectionStatus == .disconnected ? "Connect" : "Disconnect") {
                    if state.connectionStatus == .disconnected {
                        guard !state.selectedPort.isEmpty else { return }
                        device.connect(port: state.selectedPort, baudRate: Int32(state.selectedBaud))
                        state.connectionStatus = .connected
                        state.addLog("Connected to \(state.selectedPort) at \(state.selectedBaud) baud", type: .connected)
                        state.appendToMonitor("Connected to \(state.selectedPort) at \(state.selectedBaud) baud\n")
                    } else {
                        device.disconnect()
                        serial.disconnect()
                        state.connectionStatus = .disconnected
                        state.addLog("Disconnected from device", type: .disconnected)
                        state.appendToMonitor("Disconnected from device\n")
                    }
                }
                .disabled(state.connectionStatus == .disconnected && state.selectedPort.isEmpty)
                .foregroundColor(state.connectionStatus == .disconnected ? .green : .red)
            }

            HStack {
                Text("Port:")
                    .frame(width: 50, alignment: .leading)
                Picker("", selection: Binding(
                    get: { serial.availablePorts.contains(state.selectedPort) ? state.selectedPort : "" },
                    set: { state.selectedPort = $0 }
                )) {
                    if state.selectedPort.isEmpty && !serial.availablePorts.isEmpty {
                        Text("Select a port...").tag("")
                    }
                    ForEach(serial.availablePorts, id: \.self) { port in
                        Text(port).tag(port)
                    }
                    if serial.availablePorts.isEmpty {
                        Text("No ports found").tag("")
                    }
                }
                .frame(minWidth: 220)
                Button("Refresh Ports") {
                    serial.refreshPorts()
                }
            }

            HStack {
                Text("Baud:")
                    .frame(width: 50, alignment: .leading)
                Picker("", selection: $state.selectedBaud) {
                    Text("1200").tag(1200)
                    Text("9600").tag(9600)
                }
                .frame(width: 80)
            }

            Divider()

            HStack {
                Text("Host Mode").font(.headline)
                Spacer()
                Button(state.connectionStatus == .hostMode ? "Disconnect Host" : "Open Host") {
                    if state.connectionStatus == .hostMode {
                        device.exitHostMode()
                        state.connectionStatus = .connected
                    } else {
                        device.enterHostMode()
                        state.adminOpenSequence = true
                        state.expectingRevisionCode = true
                    }
                }
                .disabled(state.connectionStatus == .disconnected)
            }

            Text("Enter Host Mode to query device status and firmware revision. Requires an active connection.")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }
}
