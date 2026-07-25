import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WK3App")
                        .font(.title)
                        .fontWeight(.semibold)
                    Text("Version 1.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Text("Native macOS app for controlling WK3/WKUSB Morse code keyer devices.")
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Text("License: BSD 2-Clause License")
            Text("Copyright (c) 2026 William Eggers")
            Link("https://github.com/williameggers/WK3App",
                    destination: URL(string: "https://github.com/williameggers/WK3App")!)
                .font(.callout)

            Divider()

            VStack(alignment: .leading, spacing: 4) {
                Text("Based on WK3GUI by Josh Peterson.")
                Link("https://github.com/joshpeterson1/wk3GUI",
                     destination: URL(string: "https://github.com/joshpeterson1/wk3GUI")!)
                    .font(.callout)
            }

            Divider()

            HStack {
                Spacer()
                Button("Close") {
                    dismiss()
                }
                .controlSize(.large)
            }
        }
        .padding()
        .frame(minWidth: 420)
    }
}
