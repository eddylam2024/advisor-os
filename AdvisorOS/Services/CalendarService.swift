import EventKit
import Foundation
import SwiftData

/// Reads the calendars already set up on this Mac (iCloud, Google, Exchange / Microsoft 365) through EventKit.
/// No sign-in and no API costs.
@Observable
final class CalendarService {
    private let store = EKEventStore()
    private(set) var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)
    private(set) var lastSync: Date?
    private(set) var lastError: String?
    private var observer: NSObjectProtocol?
    private var observedContext: ModelContext?

    /// The advisor's choice inside the app. macOS permission is separate and can only be revoked in System Settings.
    var isConnected: Bool {
        didSet { UserDefaults.standard.set(isConnected, forKey: Keys.connected) }
    }

    /// Calendars the advisor marked as work. `nil` means "not chosen yet", which reads every calendar.
    private(set) var workCalendarIDs: Set<String>? {
        didSet { UserDefaults.standard.set(workCalendarIDs.map(Array.init), forKey: Keys.workCalendars) }
    }

    private enum Keys {
        static let connected = "calendarConnected"
        static let workCalendars = "workCalendarIDs"
    }

    init() {
        let defaults = UserDefaults.standard
        // Builds before Connect / Disconnect existed treated granted access as connected.
        isConnected = defaults.object(forKey: Keys.connected) as? Bool
            ?? (EKEventStore.authorizationStatus(for: .event) == .fullAccess)
        workCalendarIDs = defaults.stringArray(forKey: Keys.workCalendars).map(Set.init)
    }

    var hasAccess: Bool { status == .fullAccess }
    var isSyncing: Bool { isConnected && hasAccess }

    struct CalendarInfo: Identifiable, Hashable {
        let id: String
        let title: String
        let account: String
        let color: CGColor
        let isWritable: Bool
    }

    var calendars: [CalendarInfo] {
        guard hasAccess else { return [] }
        return store.calendars(for: .event)
            .map { CalendarInfo(id: $0.calendarIdentifier, title: $0.title, account: $0.source.title,
                                color: $0.cgColor, isWritable: $0.allowsContentModifications) }
            .sorted { ($0.account, $0.title) < ($1.account, $1.title) }
    }

    /// Work calendars new appointments can be written to.
    var writableWorkCalendars: [CalendarInfo] {
        calendars.filter { $0.isWritable && isWorkCalendar($0.id) }
    }

    func isWorkCalendar(_ id: String) -> Bool { workCalendarIDs?.contains(id) ?? true }

    func setWorkCalendar(_ id: String, _ isWork: Bool, context: ModelContext) {
        var ids = workCalendarIDs ?? Set(calendars.map(\.id))
        if isWork { ids.insert(id) } else { ids.remove(id) }
        workCalendarIDs = ids
        sync(into: context)
    }

    /// Call once at launch: syncs if connected and keeps appointments current when anything changes in Calendar.
    func start(context: ModelContext) {
        status = EKEventStore.authorizationStatus(for: .event)
        // When disconnected, no calendar events should linger (e.g. imported before Connect / Disconnect existed).
        if !isConnected { removeImported(from: context) }
        sync(into: context)
        guard observer == nil else { return }
        observedContext = context
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let context = self.observedContext else { return }
                self.sync(into: context)
            }
        }
    }

    func connect(context: ModelContext) async {
        if !hasAccess {
            do {
                _ = try await store.requestFullAccessToEvents()
            } catch {
                lastError = error.localizedDescription
            }
            status = EKEventStore.authorizationStatus(for: .event)
        }
        guard hasAccess else { return }
        isConnected = true
        context.log("Calendar connected", by: "Advisor")
        sync(into: context)
    }

    /// Stops syncing and removes imported appointments from Advisor OS. The calendars themselves aren't touched.
    func disconnect(context: ModelContext) {
        isConnected = false
        let count = removeImported(from: context)
        context.log("Calendar disconnected, \(count) imported appointments removed from Advisor OS", by: "Advisor")
        try? context.save()
        lastSync = nil
    }

    @discardableResult
    private func removeImported(from context: ModelContext) -> Int {
        let imported = (try? context.fetch(FetchDescriptor<Appointment>(predicate: #Predicate { $0.calendarEventID != nil }))) ?? []
        imported.forEach(context.delete)
        try? context.save()
        return imported.count
    }

    /// Imports the next 14 days of events from work calendars. Existing appointments are updated in place, keyed by
    /// event ID, so documents marked received and notes are kept. Appointments whose event was deleted, or whose
    /// calendar is no longer marked as work, are removed.
    @discardableResult
    func sync(into context: ModelContext, days: Int = 14) -> Int {
        guard isSyncing else { return 0 }
        let start = Calendar.current.startOfDay(for: .now)
        guard let end = Calendar.current.date(byAdding: .day, value: days, to: start) else { return 0 }
        let chosen = store.calendars(for: .event).filter { isWorkCalendar($0.calendarIdentifier) }
        let events: [EKEvent] = chosen.isEmpty ? [] :
            store.events(matching: store.predicateForEvents(withStart: start, end: end, calendars: chosen)).filter { !$0.isAllDay }

        let existing = (try? context.fetch(FetchDescriptor<Appointment>())) ?? []
        let clients = (try? context.fetch(FetchDescriptor<Client>())) ?? []
        var byEventID: [String: Appointment] = [:]
        for appointment in existing {
            if let id = appointment.calendarEventID { byEventID[id] = appointment }
        }

        var added = 0
        for event in events {
            let eventID = event.calendarItemIdentifier
            guard !eventID.isEmpty else { continue }
            let title = event.title ?? "Meeting"
            let minutes = max(15, Int(event.endDate.timeIntervalSince(event.startDate) / 60))
            let video = Self.videoLink(in: event)
            let format: MeetingFormat = video != nil ? .video : (event.location?.isEmpty == false ? .inPerson : .unknown)
            let email = event.attendees?.lazy.compactMap { Self.email(from: $0.url) }.first ?? ""

            if let appointment = byEventID[eventID] {
                appointment.start = event.startDate
                appointment.durationMinutes = minutes
                appointment.videoURL = video
                // Older builds guessed "phone" for events without a location. The app never sets phone itself on import.
                if appointment.format == .phone || appointment.format == .unknown { appointment.format = format }
                if appointment.clientEmail.isEmpty { appointment.clientEmail = email }
                appointment.linkClient(from: clients)
            } else {
                let appointment = Appointment(
                    clientName: EventTitleParser.clientName(from: title),
                    clientEmail: email,
                    start: event.startDate,
                    durationMinutes: minutes,
                    templateID: AppointmentTemplate.match(title: title).id,
                    format: format,
                    videoURL: video,
                    calendarEventID: eventID)
                context.insert(appointment)
                appointment.linkClient(from: clients)
                added += 1
            }
        }

        let seen = Set(events.map(\.calendarItemIdentifier))
        var removed = 0
        for appointment in existing {
            guard let id = appointment.calendarEventID, appointment.start >= start, appointment.start < end, !seen.contains(id) else { continue }
            context.delete(appointment)
            removed += 1
        }
        try? context.save()
        lastSync = .now
        if added > 0 || removed > 0 {
            context.log("Calendar sync: \(added) added, \(removed) removed", by: "System")
        }
        return events.count
    }

    /// Adds an event for an appointment created in Advisor OS and returns its identifier.
    func createEvent(for appointment: Appointment, calendarID: String) throws -> String {
        guard let calendar = store.calendar(withIdentifier: calendarID) else { throw CalendarError.calendarMissing }
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = "\(appointment.template.nameEN) – \(appointment.clientName)"
        event.startDate = appointment.start
        event.endDate = appointment.end
        if let link = appointment.videoURL, let url = URL(string: link) {
            event.url = url
            event.location = link
        }
        if !appointment.notes.isEmpty { event.notes = appointment.notes }
        try store.save(event, span: .thisEvent)
        return event.calendarItemIdentifier
    }

    /// Deletes the calendar event behind an imported appointment. Returns false if it no longer exists.
    @discardableResult
    func deleteEvent(id: String) throws -> Bool {
        guard let event = store.calendarItem(withIdentifier: id) as? EKEvent else { return false }
        try store.remove(event, span: .thisEvent)
        return true
    }

    enum CalendarError: LocalizedError {
        case calendarMissing
        var errorDescription: String? { "That calendar is no longer on this Mac. Pick another one." }
    }

    private static func videoLink(in event: EKEvent) -> String? {
        let haystack = [event.url?.absoluteString, event.location, event.notes].compactMap { $0 }.joined(separator: " ")
        let hosts = ["teams.microsoft.com", "zoom.us", "meet.google.com", "webex.com"]
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: haystack, range: NSRange(haystack.startIndex..., in: haystack)) ?? []
        return matches.compactMap(\.url).first { url in hosts.contains { url.host()?.contains($0) == true } }?.absoluteString
    }

    private static func email(from url: URL) -> String? {
        guard url.scheme == "mailto" else { return nil }
        return url.absoluteString.replacingOccurrences(of: "mailto:", with: "")
    }
}
