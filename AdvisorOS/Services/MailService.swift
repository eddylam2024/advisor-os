import AppKit
import Foundation

/// Opens emails as drafts in the Mac's default mail app (Apple Mail, Outlook, or anything else),
/// so they're sent from the advisor's own address. Nothing is sent automatically.
enum MailService {
    static func draftURL(to: String, subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = to
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: body)
        ]
        // mailto wants %20 for spaces, not +.
        components.percentEncodedQuery = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        return components.url
    }

    @discardableResult
    static func openDraft(to: String, subject: String, body: String) -> Bool {
        guard let url = draftURL(to: to, subject: subject, body: body) else { return false }
        return NSWorkspace.shared.open(url)
    }

    /// Name of the app that handles mailto: links on this Mac, e.g. "Mail" or "Microsoft Outlook".
    static var defaultMailAppName: String {
        guard let probe = URL(string: "mailto:test@example.com"),
              let appURL = NSWorkspace.shared.urlForApplication(toOpen: probe) else { return "No mail app" }
        return FileManager.default.displayName(atPath: appURL.path).replacingOccurrences(of: ".app", with: "")
    }
}
