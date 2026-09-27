import SwiftData
import SwiftUI

struct TemplatesView: View {
    @State private var selectedID = AppointmentTemplate.all[0].id
    @State private var language = "en"
    @State private var sending: AppointmentTemplate?

    private var templates: [AppointmentTemplate] { AppointmentTemplate.all.filter { $0.id != "general" } }
    private var selected: AppointmentTemplate { AppointmentTemplate.find(selectedID) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gapLarge) {
                Text("Each appointment type sets the documents a client brings and the meeting agenda.")
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], spacing: 12) {
                    ForEach(templates) { t in
                        Button { selectedID = t.id } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Pill(text: t.kind.rawValue, tint: t.kind == .lending ? .accentColor : Theme.good)
                                Text(t.nameEN).font(.headline)
                                Text("\(t.minutes) min · \(t.documents.en.count) documents").font(.caption).foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .glassEffect(.regular, in: .rect(cornerRadius: Theme.radiusCard))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.radiusCard)
                                .strokeBorder(t.id == selectedID ? Color.accentColor : .clear, lineWidth: 2)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: Theme.gap) {
                    HStack {
                        Text(selected.name(language)).font(.title2.weight(.semibold))
                        Spacer()
                        Picker("Language", selection: $language) {
                            Text("English").tag("en")
                            Text("Français").tag("fr")
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 180)
                        Button("Email Checklist…", systemImage: "envelope") { sending = selected }
                            .buttonStyle(.glass)
                    }
                    HStack(alignment: .top, spacing: Theme.gapLarge) {
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel(language == "fr" ? "Le client apporte" : "Client brings")
                            ForEach(selected.documents.list(language), id: \.self) { Label($0, systemImage: "doc") }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .leading, spacing: 8) {
                            SectionLabel("Agenda")
                            ForEach(selected.agenda, id: \.self) { Label($0, systemImage: "circle.fill").labelStyle(BulletLabelStyle()) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .glassCard()
            }
            .padding(Theme.paddingLarge)
        }
        .sheet(item: $sending) { SendChecklistSheet(template: $0, language: language) }
    }
}

/// Level 0 integration: email a client the checklist for their appointment from the advisor's own mail app.
struct SendChecklistSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("advisorName") private var advisorName = ""
    @Query(sort: \Client.name) private var clients: [Client]
    let template: AppointmentTemplate
    @State var language: String
    @State private var email = ""
    @State private var failed = false

    var body: some View {
        Form {
            Picker("Client", selection: $email) {
                Text("Type an address below").tag("")
                ForEach(clients.filter { !$0.email.isEmpty }) { Text("\($0.name) · \($0.email)").tag($0.email) }
            }
            TextField("Email", text: $email)
            Picker("Language", selection: $language) {
                Text("English").tag("en")
                Text("Français").tag("fr")
            }
            Section("Preview") {
                Text(ChecklistEmail.body(template, language: language, advisorName: advisorName))
                    .font(.callout)
                    .textSelection(.enabled)
            }
            if failed {
                Text("Couldn't open your mail app. Set a default email app in Mail › Settings › General.")
                    .foregroundStyle(.red)
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 520)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button("Open in \(MailService.defaultMailAppName)") {
                    let ok = MailService.openDraft(to: email, subject: ChecklistEmail.subject(template, language: language),
                                                   body: ChecklistEmail.body(template, language: language, advisorName: advisorName))
                    if ok {
                        context.log("\(template.nameEN) checklist opened as email draft for \(email)", by: advisorName.isEmpty ? "Advisor" : advisorName)
                        dismiss()
                    } else {
                        failed = true
                    }
                }
                .disabled(!email.contains("@"))
            }
        }
    }
}

enum ChecklistEmail {
    static func subject(_ t: AppointmentTemplate, language: String) -> String {
        language == "fr" ? "Votre rendez-vous : \(t.nameFR.lowercased())" : "Your \(t.nameEN.lowercased()) appointment"
    }

    static func body(_ t: AppointmentTemplate, language: String, advisorName: String) -> String {
        let docs = t.documents.list(language).map { "• \($0)" }.joined(separator: "\n")
        let signature = advisorName.isEmpty ? "" : "\n\(advisorName)"
        if language == "fr" {
            return """
            Bonjour,

            Pour préparer notre rencontre (\(t.nameFR.lowercased()), environ \(t.minutes) minutes), merci d'apporter ou de m'envoyer les documents suivants :

            \(docs)

            Si un document vous manque, apportez ce que vous avez. Nous verrons le reste ensemble.

            Au plaisir,\(signature)
            """
        }
        return """
        Hi,

        To get the most out of our \(t.nameEN.lowercased()) (about \(t.minutes) minutes), please bring or send me the following:

        \(docs)

        If you can't find something, bring what you have and we'll sort out the rest together.

        Talk soon,\(signature)
        """
    }
}
