import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("advisorName") private var advisorName = ""
    @AppStorage("advisorEmail") private var advisorEmail = ""
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @Query(filter: #Predicate<Appointment> { $0.isDemo }) private var demoAppointments: [Appointment]

    var body: some View {
        Form {
            Section("You") {
                TextField("Name", text: $advisorName, prompt: Text("Used to sign emails and in the audit trail"))
                TextField("Email", text: $advisorEmail)
            }
            Section("Mac") {
                Toggle("Show next appointment in the menu bar", isOn: $showMenuBarExtra)
            }
            Section {
                if demoAppointments.isEmpty {
                    Button("Load Demo Data") { DemoData.load(into: context) }
                } else {
                    Button("Remove Demo Data", role: .destructive) { DemoData.remove(from: context) }
                }
            } header: {
                Text("Demo data")
            } footer: {
                Text("Fictional clients and appointments for trying the app. Your own data isn't touched.")
            }
            Section {
                LabeledContent("Stored", value: "Only on this Mac")
                LabeledContent("Drafting", value: "On-device, or templates")
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "–")
            } header: {
                Text("Privacy")
            } footer: {
                Text("Personal project for educational purposes. Not financial advice, and not affiliated with any employer.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }
}
