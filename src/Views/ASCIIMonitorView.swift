import SwiftUI
import AppKit

struct ASCIIMonitorView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ASCII Monitor").font(.headline)
                Spacer()
                Button("Copy") {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(state.asciiMonitorText, forType: .string)
                }
                .buttonStyle(.bordered)
                Button("Clear") { state.clearMonitor() }
                    .buttonStyle(.bordered)
            }

            ScrollView(.vertical) {
                Text(state.asciiMonitorText.isEmpty ? "No data received yet" : state.asciiMonitorText)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.green)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .background(Color(red: 0.17, green: 0.22, blue: 0.27))
            .frame(minHeight: 100, maxHeight: 150)
            .cornerRadius(6)
        }
        .padding()
    }
}
