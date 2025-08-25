import SwiftUI

struct SettingsView: View {
    @AppStorage("showTimeWhileRunning") private var showTimeWhileRunning: Bool = false
    @AppStorage("keepScreenOn") private var keepScreenOn: Bool = true
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Show remaining time while running", isOn: $showTimeWhileRunning)
                Toggle("Keep screen on during session", isOn: $keepScreenOn)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
