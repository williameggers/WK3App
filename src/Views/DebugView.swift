import SwiftUI

private struct LogScrollHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct LogContentBottomKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct DebugView: View {
    @ObservedObject var state: AppState
    @ObservedObject var device: WK3Device

    @State private var isAtBottom = true
    @State private var scrollHeight: CGFloat = 0
    @State private var contentBottomY: CGFloat = 0

    private let maxDisplayedEntries = 500

    private var displayedEntries: [LogEntry] {
        if state.logEntries.count <= maxDisplayedEntries {
            return state.logEntries
        }
        return Array(state.logEntries.suffix(maxDisplayedEntries))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug").font(.headline)

            HStack {
                Text("Command:")
                    .frame(width: 80, alignment: .leading)
                TextField("Enter hex (e.g., 48656C6C6F)", text: $state.commandInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Button("Send") {
                    _ = device.sendRawHex(state.commandInput)
                    state.commandInput = ""
                }
                .disabled(state.connectionStatus == .disconnected)
            }

            logScrollView

            HStack {
                Button("Copy") {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "HH:mm:ss"
                    let text = state.logEntries.map { "[\(formatter.string(from: $0.timestamp))] \($0.message)" }.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                .buttonStyle(.bordered)
                Button("Clear Log") { state.clearLog() }
                    .buttonStyle(.bordered)
                Button("Run Basic WK3 Test") {
                    device.resetDevice()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        _ = device.sendBytes([0x00, 0x02])
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        _ = device.sendBytes([0x00, 0x04])
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.1) {
                        _ = device.sendBytes([0x41])
                    }
                }
                .disabled(state.connectionStatus == .disconnected)
            }
        }
        .padding()
    }

    private var logScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(displayedEntries) { entry in
                        HStack(alignment: .top) {
                            Text(entry.timestamp, style: .time)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.gray)
                            Text(entry.message)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(entry.type.color)
                        }
                    }

                    Color.clear
                        .frame(height: 1)
                        .id("bottomAnchor")
                }
                .padding(6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(GeometryReader { geo in
                    Color.clear.preference(
                        key: LogContentBottomKey.self,
                        value: geo.frame(in: .named("logScrollSpace")).maxY
                    )
                })
            }
            .coordinateSpace(name: "logScrollSpace")
            .background(GeometryReader { geo in
                Color.clear.preference(key: LogScrollHeightKey.self, value: geo.size.height)
            })
            .onPreferenceChange(LogScrollHeightKey.self) { scrollHeight = $0 }
            .onPreferenceChange(LogContentBottomKey.self) { y in
                contentBottomY = y
                let atBottom = y <= scrollHeight + 2
                if atBottom != isAtBottom {
                    isAtBottom = atBottom
                }
            }
            .onChange(of: state.logEntries.count) { _ in
                if isAtBottom {
                    DispatchQueue.main.async {
                        withAnimation {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                    }
                }
            }
            .background(Color(red: 0.1, green: 0.12, blue: 0.17))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: 150, maxHeight: 300)
            .cornerRadius(6)
            .overlay(alignment: .bottomTrailing) {
                if !isAtBottom {
                    Button {
                        withAnimation {
                            proxy.scrollTo("bottomAnchor", anchor: .bottom)
                        }
                        isAtBottom = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.down")
                            Text("Latest")
                        }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .transition(.opacity)
                    .animation(.easeInOut, value: isAtBottom)
                }
            }
        }
    }
}
