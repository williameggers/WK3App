import SwiftUI

struct WKModeView: View {
    @ObservedObject var state: AppState
    @ObservedObject var device: WK3Device

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WKMode Settings").font(.headline)

            HStack {
                Text("Paddle:")
                    .frame(width: 122, alignment: .leading)
                Toggle("Disable Paddle Watchdog", isOn: $state.paddleWatchdogDisabled)
                    .onChange(of: state.paddleWatchdogDisabled) { _ in
                        device.setModeRegister(state.modeRegister)
                        state.addLog("Paddle Watchdog: \(state.paddleWatchdogDisabled ? "DISABLED" : "ENABLED")", type: .sent)
                    }
                Toggle("Paddle Echo", isOn: $state.paddleEchoEnabled)
                    .onChange(of: state.paddleEchoEnabled) { _ in
                        device.setModeRegister(state.modeRegister)
                        state.addLog("Paddle Echo: \(state.paddleEchoEnabled ? "ON" : "OFF")", type: .sent)
                    }
            }

            HStack {
                Text("Spacing:")
                    .frame(width: 122, alignment: .leading)
                Toggle("Autospace", isOn: $state.autospaceEnabled)
                    .onChange(of: state.autospaceEnabled) { _ in
                        device.setModeRegister(state.modeRegister)
                        state.addLog("Autospace: \(state.autospaceEnabled ? "ON" : "OFF")", type: .sent)
                    }
                Toggle("Contest Spacing", isOn: $state.contestSpacingEnabled)
                    .onChange(of: state.contestSpacingEnabled) { _ in
                        device.setModeRegister(state.modeRegister)
                        state.addLog("Contest Spacing: \(state.contestSpacingEnabled ? "ON" : "OFF")", type: .sent)
                    }
            }

            HStack {
                Text("Serial:")
                    .frame(width: 122, alignment: .leading)
                Toggle("Serial Echo Back", isOn: $state.serialEchoEnabled)
                    .onChange(of: state.serialEchoEnabled) { _ in
                        device.setModeRegister(state.modeRegister)
                        state.addLog("Serial Echo Back: \(state.serialEchoEnabled ? "ON" : "OFF")", type: .sent)
                    }
            }
        }
        .padding()
    }
}
