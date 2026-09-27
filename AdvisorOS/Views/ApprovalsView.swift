import SwiftData
import SwiftUI

struct ApprovalsView: View {
    enum Tab: String, CaseIterable { case drafts = "Drafts", audit = "Audit trail" }

    @Environment(\.modelContext) private var context
    @AppStorage("advisorName") private var advisorName = ""
    @Query(sort: \Draft.createdAt, order: .reverse) private var drafts: [Draft]
    @Query(sort: \AuditEntry.date, order: .reverse) private var audit: [AuditEntry]
    @State private var tab: Tab = .drafts
    @State private var selectedID: PersistentIdentifier?
    @State private var mailError = false

    private var ordered: [Draft] {
        drafts.filter { $0.status == .ready } + drafts.filter { $0.status == .approved }
    }

    private var selected: Draft? {
        drafts.first { $0.persistentModelID == selectedID } ?? ordered.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            Picker("View", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 260)

            switch tab {
            case .drafts: draftsView
            case .audit: auditView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(Theme.paddingLarge)
        .alert("Couldn't open your mail app", isPresented: $mailError) {} message: {
            Text("Set a default email app in Mail › Settings › General, then try again.")
        }
    }

    @ViewBuilder private var draftsView: some View {
        if drafts.isEmpty {
            EmptyStateView(title: "No drafts yet", systemImage: "tray",
                           message: "Open an appointment in Today and choose a draft type.")
        } else {
            HStack(alignment: .top, spacing: Theme.gapLarge) {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(ordered) { draft in
                            Button { selectedID = draft.persistentModelID } label: {
                                HStack(spacing: 12) {
                                    Avatar(name: draft.clientName)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(draft.clientName).font(.body.weight(.medium))
                                        Text(draft.kind.label).font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if draft.status == .approved, let at = draft.approvedAt {
                                        Pill(text: "Approved \(at.formatted(date: .omitted, time: .shortened))", tint: Theme.good)
                                    } else {
                                        Pill(text: "To review", tint: .accentColor)
                                    }
                                }
                                .padding(12)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular, in: .rect(cornerRadius: Theme.radiusBox))
                            .overlay {
                                RoundedRectangle(cornerRadius: Theme.radiusBox)
                                    .strokeBorder(draft.persistentModelID == selected?.persistentModelID ? Color.accentColor : .clear, lineWidth: 2)
                            }
                        }
                    }
                    .padding(2)
                }
                .frame(width: 320)

                if let selected { DraftEditor(draft: selected, onApprove: approve) }
            }
        }
    }

    private var auditView: some View {
        Table(audit) {
            TableColumn("Time") { Text($0.date.formatted(date: .abbreviated, time: .shortened)).monospacedDigit() }
                .width(160)
            TableColumn("What happened", value: \.action)
            TableColumn("By", value: \.actor).width(120)
        }
        .alternatingRowBackgrounds(.disabled)
        .scrollContentBackground(.hidden)
        .padding(6)
        .glassEffect(.regular, in: .rect(cornerRadius: Theme.radiusCard))
    }

    private func approve(_ draft: Draft) {
        let by = advisorName.isEmpty ? "Advisor" : advisorName
        draft.status = .approved
        draft.approvedAt = .now
        draft.approvedBy = by
        context.log("\(draft.kind.label) for \(draft.clientName) approved", by: by)
        if draft.kind.isEmail {
            let subject = switch (draft.kind, draft.language) {
            case (.reminder, "fr"): "Votre rendez-vous à venir"
            case (_, "fr"): "Suivi de notre rencontre"
            case (.reminder, _): "Your upcoming appointment"
            default: "Following up on our meeting"
            }
            if MailService.openDraft(to: draft.clientEmail, subject: subject, body: draft.text) {
                context.log("\(draft.kind.label) for \(draft.clientName) opened in \(MailService.defaultMailAppName)", by: by)
            } else {
                mailError = true
            }
        }
        selectedID = ordered.first { $0.status == .ready }?.persistentModelID
    }
}

struct DraftEditor: View {
    @Bindable var draft: Draft
    let onApprove: (Draft) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.gap) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    SectionLabel(draft.kind.label)
                    Text(draft.clientName).font(.title2.weight(.semibold))
                }
                Spacer()
                if draft.language == "fr" { Pill(text: "Français", tint: .accentColor) }
                Pill(text: draft.status == .approved ? "Approved by \(draft.approvedBy ?? "advisor")" : "Drafted by \(draft.generatedBy)",
                     tint: draft.status == .approved ? Theme.good : .accentColor)
            }
            TextEditor(text: $draft.text)
                .font(.body)
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(.quaternary.opacity(0.5), in: .rect(cornerRadius: Theme.radiusBox))
                .disabled(draft.status == .approved)
            if draft.status == .ready {
                HStack {
                    Text(draft.kind.isEmail ? "Approving opens this as a draft in your mail app. You send it from there." : "Approving locks this version in the audit trail.")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                    Button(draft.kind.isEmail ? "Approve and Open in Mail" : "Approve", systemImage: "checkmark") { onApprove(draft) }
                        .buttonStyle(.glassProminent)
                        .keyboardShortcut(.return, modifiers: .command)
                }
            } else if let at = draft.approvedAt {
                Text("Approved \(at.formatted(date: .abbreviated, time: .shortened)). This version is locked.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .glassCard()
    }
}
