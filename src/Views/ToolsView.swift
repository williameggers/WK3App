import SwiftUI

struct ToolsView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Tools").font(.headline)
                Spacer()
                Button("Settings") {
                    state.showToolSettings = true
                }
                .buttonStyle(.bordered)
                .disabled(!state.keyboardEmulationActive && !state.morseInvadersActive)
            }

            HStack {
                Toggle("Keyboard Emulation", isOn: $state.keyboardEmulationActive)
                    .onChange(of: state.keyboardEmulationActive) { newValue in
                        if newValue {
                            state.morseInvadersActive = false
                            state.emulationStatus = "Active - Paddle input will be typed system-wide"
                        } else {
                            state.emulationStatus = ""
                        }
                        state.addLog("Keyboard emulation \(newValue ? "enabled" : "disabled")", type: newValue ? .connected : .disconnected)
                    }

                Toggle("Morse Invaders", isOn: $state.morseInvadersActive)
                    .onChange(of: state.morseInvadersActive) { newValue in
                        if newValue {
                            state.keyboardEmulationActive = false
                            state.capsLockEnabled = true
                            state.emulationStatus = "MorseInvaders Active - Dit (L_CTRL), Dah (R_CTRL)"
                        } else {
                            state.emulationStatus = ""
                        }
                        state.addLog("MorseInvaders \(newValue ? "enabled" : "disabled")", type: newValue ? .connected : .disconnected)
                    }

                Spacer()

                Text(state.emulationStatus)
                    .font(.headline)
                    .foregroundColor(state.emulationStatus.contains("Active") ? .secondary : .secondary)
            }
        }
        .padding()
        .sheet(isPresented: $state.showToolSettings) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Tool Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
                Divider()

                if state.keyboardEmulationActive {
                    Toggle("CAPS LOCK", isOn: $state.capsLockEnabled)
                        .toggleStyle(.checkbox)
                }

                if state.morseInvadersActive {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MorseInvaders Timing").font(.headline)
                        
                        Spacer()

                        HStack {
                            Text("Key Duration:")
                                .frame(width: 130, alignment: .trailing)
                            Slider(value: $state.keyDuration, in: 5...300, step: 5)
                            Text("\(Int(state.keyDuration)) ms")
                                .frame(width: 55)
                        }

                        HStack {
                            Text("Delay Between Keys:")
                                .frame(width: 130, alignment: .trailing)
                            Slider(value: $state.keyDelay, in: 5...300, step: 5)
                            Text("\(Int(state.keyDelay)) ms")
                                .frame(width: 55)
                        }

                        HStack {
                            Text("Letter Spacing:")
                                .frame(width: 130, alignment: .trailing)
                            Slider(value: $state.letterSpacing, in: 5...800, step: 5)
                            Text("\(Int(state.letterSpacing)) ms")
                                .frame(width: 55)
                        }
                    }
                }

                if !state.keyboardEmulationActive && !state.morseInvadersActive {
                    Text("Select a tool to configure its settings.")
                        .foregroundColor(.secondary)
                }

                Spacer()
                HStack {
                    Spacer()
                    Button("Close") {
                        state.showToolSettings = false
                    }
                    .controlSize(.large)
                }
            }
            .padding()
            .frame(minWidth: 400, minHeight: 200)
        }
    }
}
