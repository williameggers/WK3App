import SwiftUI

struct KeyerSettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject var device: WK3Device

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Keyer Settings").font(.headline)
                Spacer()
                Button("Advanced Settings") {
                    state.showAdvancedSettings = true
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Text("Keyer Mode:")
                    .frame(width: 110, alignment: .leading)
                Picker("", selection: $state.keyerMode) {
                    ForEach(KeyerMode.allCases) { mode in
                        Text(mode.name).tag(mode)
                    }
                }
                .frame(width: 120)
                .onChange(of: state.keyerMode) { _ in
                    device.setModeRegister(state.modeRegister)
                }

                Button(state.paddleSwapped ? "Unswap Paddles" : "Swap Paddles") {
                    state.paddleSwapped.toggle()
                    device.setModeRegister(state.modeRegister)
                    state.addLog("Paddle swap: \(state.paddleSwapped ? "ON" : "OFF")", type: .sent)
                }
                .buttonStyle(.bordered)
                .tint(state.paddleSwapped ? .red : .accentColor)

                Button(state.sidetoneEnabled ? "Disable Sidetone" : "Enable Sidetone") {
                    state.sidetoneEnabled.toggle()
                    device.setPinConfig(state.pinConfig)
                    state.addLog("Sidetone: \(state.sidetoneEnabled ? "ON" : "OFF")", type: .sent)
                }
                .buttonStyle(.bordered)
                .tint(state.sidetoneEnabled ? .red : .accentColor)
            }

            HStack {
                Text("Speed (WPM):")
                    .frame(width: 120, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(state.currentWPM) },
                    set: { state.currentWPM = Int($0) }
                ), in: 5...50, step: 1)
                .frame(minWidth: 200)
                Text("\(state.currentWPM) WPM")
                    .frame(width: 60)
                Button("Set Speed") {
                    device.setWPM(state.currentWPM)
                }
                .buttonStyle(.bordered)
                .disabled(state.connectionStatus != .hostMode)
            }

            HStack {
                Text("Key Compensation:")
                    .frame(width: 120, alignment: .leading)
                Slider(value: Binding(
                    get: { Double(state.currentKeyComp) },
                    set: { state.currentKeyComp = Int($0) }
                ), in: 0...50, step: 1)
                .frame(minWidth: 200)
                Text("\(state.currentKeyComp) ms")
                    .frame(width: 60)
                Button("Set Compensation") {
                    device.setKeyCompensation(state.currentKeyComp)
                }
                .buttonStyle(.bordered)
                .disabled(state.connectionStatus != .hostMode)
            }
        }
        .padding()
    }
}
