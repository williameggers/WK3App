import SwiftUI

struct PinCFGView: View {
    @ObservedObject var state: AppState
    @ObservedObject var device: WK3Device

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PinCFG Settings").font(.headline)

            HStack {
                Text("Hangtime:")
                    .frame(width: 105, alignment: .leading)
                Picker("", selection: $state.hangtimeSetting) {
                    ForEach(Hangtime.allCases) { ht in
                        Text(ht.name).tag(ht)
                    }
                }
                .frame(width: 200)
                .onChange(of: state.hangtimeSetting) { _ in
                    device.setPinConfig(state.pinConfig)
                }
            }

            HStack {
                Text("Output:")
                    .frame(width: 122, alignment: .leading)
                Toggle("Key Out 1", isOn: $state.keyout1Enabled)
                    .onChange(of: state.keyout1Enabled) { _ in
                        device.setPinConfig(state.pinConfig)
                        state.addLog("Key Out 1: \(state.keyout1Enabled ? "ON" : "OFF")", type: .sent)
                    }
                Toggle("Key Out 2", isOn: $state.keyout2Enabled)
                    .onChange(of: state.keyout2Enabled) { _ in
                        device.setPinConfig(state.pinConfig)
                        state.addLog("Key Out 2: \(state.keyout2Enabled ? "ON" : "OFF")", type: .sent)
                    }
                Toggle("PTT Enable", isOn: $state.pttEnabled)
                    .onChange(of: state.pttEnabled) { _ in
                        device.setPinConfig(state.pinConfig)
                        state.addLog("PTT: \(state.pttEnabled ? "ON" : "OFF")", type: .sent)
                    }
            }
        }
        .padding()
    }
}
