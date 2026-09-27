import Foundation

/// Imports and exports clients as CSV so advisors can bring their book from any CRM and take it with them.
nonisolated enum ClientCSV {
    static let header = ["name", "email", "phone", "language", "kyc_review_due", "source", "notes"]

    struct Row: Equatable {
        var name: String
        var email: String = ""
        var phone: String = ""
        var language: String = "en"
        var kycReviewDue: Date?
        var notes: String = ""
    }

    private static let dateFormat: Date.ISO8601FormatStyle = .iso8601.year().month().day()

    static func export(_ clients: [Client]) -> String {
        var lines = [header.joined(separator: ",")]
        for c in clients {
            let fields = [c.name, c.email, c.phone, c.preferredLanguage,
                          c.kycReviewDue.map { $0.formatted(dateFormat) } ?? "", c.source, c.notes]
            lines.append(fields.map(escape).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Accepts common column names from CRM exports ("Full Name", "E-mail", "Courriel"…). Rows without a name are skipped.
    static func parse(_ text: String) -> [Row] {
        let records = parseRecords(text)
        guard let head = records.first else { return [] }
        let keys = head.map { $0.lowercased().trimmingCharacters(in: .whitespaces) }
        func index(_ names: [String]) -> Int? { keys.firstIndex { names.contains($0) } }
        let iName = index(["name", "full name", "client", "client name", "nom"])
        let iFirst = index(["first name", "first", "prénom", "prenom"])
        let iLast = index(["last name", "last", "nom de famille"])
        let iEmail = index(["email", "e-mail", "email address", "courriel"])
        let iPhone = index(["phone", "phone number", "mobile", "téléphone", "telephone"])
        let iLang = index(["language", "langue"])
        let iKyc = index(["kyc_review_due", "kyc review due", "kyc due"])
        let iNotes = index(["notes", "note"])

        return records.dropFirst().compactMap { r in
            func field(_ i: Int?) -> String {
                guard let i, i < r.count else { return "" }
                return r[i].trimmingCharacters(in: .whitespaces)
            }
            var name = field(iName)
            if name.isEmpty { name = [field(iFirst), field(iLast)].filter { !$0.isEmpty }.joined(separator: " ") }
            guard !name.isEmpty else { return nil }
            let lang = field(iLang).lowercased().hasPrefix("fr") ? "fr" : "en"
            return Row(name: name, email: field(iEmail), phone: field(iPhone), language: lang,
                       kycReviewDue: try? dateFormat.parse(field(iKyc)), notes: field(iNotes))
        }
    }

    private static func escape(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    /// Minimal RFC 4180 reader: quoted fields, escaped quotes, commas and newlines inside quotes.
    static func parseRecords(_ text: String) -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var inQuotes = false
        var chars = Array(text.replacingOccurrences(of: "\r\n", with: "\n"))[...]
        while let c = chars.popFirst() {
            if inQuotes {
                if c == "\"" {
                    if chars.first == "\"" { field.append("\""); chars.removeFirst() } else { inQuotes = false }
                } else {
                    field.append(c)
                }
            } else {
                switch c {
                case "\"": inQuotes = true
                case ",": record.append(field); field = ""
                case "\n":
                    record.append(field); field = ""
                    if record != [""] { records.append(record) }
                    record = []
                default: field.append(c)
                }
            }
        }
        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            records.append(record)
        }
        return records
    }
}
