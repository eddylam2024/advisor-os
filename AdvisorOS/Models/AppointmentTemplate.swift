import Foundation

nonisolated struct Localized: Hashable, Sendable {
    let en: [String]
    let fr: [String]

    func list(_ language: String) -> [String] { language == "fr" ? fr : en }
}

/// Canadian appointment types. Each one sets the documents a client brings and the meeting agenda.
/// Lists are starting points to confirm with pilot advisors and lenders.
nonisolated struct AppointmentTemplate: Identifiable, Hashable, Sendable {
    enum Kind: String, Sendable { case lending = "Lending", advice = "Advice" }

    let id: String
    let nameEN: String
    let nameFR: String
    let kind: Kind
    let minutes: Int
    let keywords: [String]
    let documents: Localized
    let agenda: [String]

    func name(_ language: String) -> String { language == "fr" ? nameFR : nameEN }

    static let all: [AppointmentTemplate] = [
        AppointmentTemplate(
            id: "renewal", nameEN: "Mortgage renewal", nameFR: "Renouvellement hypothécaire", kind: .lending, minutes: 45,
            keywords: ["renewal", "renouvellement", "renew"],
            documents: Localized(
                en: ["Current mortgage statement", "Renewal offer from your lender", "Latest property tax bill", "Home insurance declaration"],
                fr: ["Relevé hypothécaire actuel", "Offre de renouvellement de votre prêteur", "Dernier compte de taxes foncières", "Déclaration d'assurance habitation"]),
            agenda: ["Maturity date and current terms", "Changes in income or household", "Compare the renewal offer with a switch", "Prepayment and amortization options"]),
        AppointmentTemplate(
            id: "preapproval", nameEN: "Mortgage pre-approval", nameFR: "Préapprobation hypothécaire", kind: .lending, minutes: 60,
            keywords: ["pre-approval", "preapproval", "préapprobation", "first home", "purchase"],
            documents: Localized(
                en: ["Government photo ID", "Letter of employment", "2 recent pay stubs", "CRA Notices of Assessment, last 2 years", "90 days of down payment history", "Gift letter, if family is helping"],
                fr: ["Pièce d'identité avec photo", "Lettre d'emploi", "2 talons de paie récents", "Avis de cotisation de l'ARC, 2 dernières années", "Historique de 90 jours de la mise de fonds", "Lettre de don, si la famille aide"]),
            agenda: ["Budget and target area", "Down payment sources, including FHSA and the RRSP Home Buyers' Plan", "Stress test at the current qualifying rate", "Next steps and documents still needed"]),
        AppointmentTemplate(
            id: "review", nameEN: "Annual review", nameFR: "Revue annuelle", kind: .advice, minutes: 60,
            keywords: ["review", "revue", "annual", "annuelle"],
            documents: Localized(
                en: ["Latest CRA Notice of Assessment", "TFSA room from CRA My Account", "Statements held elsewhere", "Pension statement, if any"],
                fr: ["Dernier avis de cotisation de l'ARC", "Droits CELI de Mon dossier ARC", "Relevés détenus ailleurs", "Relevé de régime de retraite, s'il y a lieu"]),
            agenda: ["Life changes since last review", "Goals and timelines", "KYC refresh: risk profile, time horizon, finances", "RRSP, TFSA and FHSA contributions", "Rebalancing and next review date"]),
        AppointmentTemplate(
            id: "open", nameEN: "New account opening", nameFR: "Ouverture de compte", kind: .advice, minutes: 45,
            keywords: ["new account", "account opening", "ouverture", "open account", "onboarding"],
            documents: Localized(
                en: ["Government photo ID", "SIN, for registered accounts", "Void cheque", "Transfer statement from current institution"],
                fr: ["Pièce d'identité avec photo", "NAS, pour les comptes enregistrés", "Chèque annulé", "Relevé de transfert de l'institution actuelle"]),
            agenda: ["Account types: TFSA, RRSP, FHSA, RESP, non-registered", "Verify ID with an accepted method and record it", "Risk tolerance and KYC", "Beneficiaries and successor holders", "Transfers in"]),
        AppointmentTemplate(
            id: "heloc", nameEN: "Line of credit / HELOC", nameFR: "Marge de crédit hypothécaire", kind: .lending, minutes: 45,
            keywords: ["heloc", "line of credit", "marge", "loc"],
            documents: Localized(
                en: ["Government photo ID", "2 recent pay stubs", "Latest Notice of Assessment", "Mortgage statement and property tax bill"],
                fr: ["Pièce d'identité avec photo", "2 talons de paie récents", "Dernier avis de cotisation", "Relevé hypothécaire et compte de taxes"]),
            agenda: ["Purpose and amount", "Existing debts and payments", "Total borrowing against the home versus the loan-to-value limit", "Repayment plan"]),
        AppointmentTemplate(
            id: "general", nameEN: "General meeting", nameFR: "Rencontre générale", kind: .advice, minutes: 30,
            keywords: [],
            documents: Localized(en: [], fr: []),
            agenda: ["Client's questions", "Next steps"])
    ]

    static func find(_ id: String) -> AppointmentTemplate {
        all.first { $0.id == id } ?? all.last!
    }

    /// Picks a template from a calendar event title, e.g. "Annual review – J. Martin".
    static func match(title: String) -> AppointmentTemplate {
        let lower = title.lowercased()
        return all.first { template in template.keywords.contains { lower.contains($0) } } ?? find("general")
    }
}

nonisolated enum EventTitleParser {
    /// Pulls a client name out of titles like "Annual review – J. Martin", "J. Martin: renewal" or "Review with J. Martin".
    static func clientName(from title: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        let lower = trimmed.lowercased()
        if let range = lower.range(of: " with ") ?? lower.range(of: " avec ") {
            return String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        for separator in [" – ", " — ", " - ", ": ", " | "] {
            let parts = trimmed.components(separatedBy: separator)
            guard parts.count >= 2 else { continue }
            let first = parts[0].trimmingCharacters(in: .whitespaces)
            let last = parts[parts.count - 1].trimmingCharacters(in: .whitespaces)
            // Whichever side doesn't read like an appointment type is the client.
            let firstIsType = AppointmentTemplate.match(title: first).id != "general"
            return firstIsType ? last : first
        }
        return trimmed
    }
}
