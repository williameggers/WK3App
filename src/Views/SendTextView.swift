import SwiftUI

struct SendTextView: View {
    @ObservedObject var state: AppState
    @ObservedObject var device: WK3Device

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Send Text to WK3").font(.headline)
                Spacer()
                Button("Clear") { state.sendText = "" }
                    .buttonStyle(.bordered)
            }

            TextEditor(text: $state.sendText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 80)
                .border(Color.gray.opacity(0.4), width: 1)
                .onChange(of: state.sendText) { _ in
                    state.updateCharCount()
                }

            HStack {
                Button("Send Text") {
                    guard !state.sendText.isEmpty else { return }
                    let upper = state.sendText.uppercased()
                    if device.sendText(upper) {
                        state.addLog("Sent text: \"\(upper)\"", type: .sent)
                        state.addLog("    Original: \"\(state.sendText)\"", type: .sent)
                        state.addLog("    Length: \(upper.count) bytes", type: .sent)
                    } else {
                        state.addLog("Failed to send text", type: .error)
                    }
                }
                .disabled(state.connectionStatus == .disconnected || state.sendText.isEmpty)

                Spacer()

                Text("\(state.charCount) characters")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("Text will be converted to uppercase and sent as raw ASCII bytes to the WK3 device.")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
    }
}
