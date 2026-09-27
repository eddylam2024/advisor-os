import Foundation
import SwiftData

/// Fictional sample data so the app shows something useful before calendar access is granted.
enum DemoData {
    static func load(into context: ModelContext) {
        let today = Calendar.current.startOfDay(for: .now)
        func at(_ hour: Int, _ minute: Int, dayOffset: Int = 0) -> Date {
            let day = Calendar.current.date(byAdding: .day, value: dayOffset, to: today)!
            return Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
        }

        let review = AppointmentTemplate.find("review").documents.en
        let open = AppointmentTemplate.find("open").documents.en
        let renewal = AppointmentTemplate.find("renewal").documents.en
        let pre = AppointmentTemplate.find("preapproval").documents.en

        let appointments = [
            Appointment(clientName: "J. Martin", clientEmail: "j.martin@example.com", start: at(10, 0), durationMinutes: 60,
                        templateID: "review", format: .video, videoURL: "https://teams.microsoft.com/l/meetup-join/demo",
                        receivedDocuments: review, notes: "Asked about RRSP room three weeks ago. Beneficiary update pending.", isDemo: true),
            Appointment(clientName: "R. Gagnon", clientEmail: "r.gagnon@example.com", start: at(13, 30), durationMinutes: 45,
                        templateID: "open", format: .inPerson, receivedDocuments: Array(open.prefix(2)),
                        notes: "Wants an FHSA and to move a TFSA from another bank.", isDemo: true),
            Appointment(clientName: "A. Nguyen", clientEmail: "a.nguyen@example.com", start: at(15, 0), durationMinutes: 45,
                        templateID: "renewal", format: .video, videoURL: "https://zoom.us/j/demo",
                        receivedDocuments: Array(renewal.prefix(3)), notes: "5-year fixed, renews in 97 days. Plans to stay.", isDemo: true),
            Appointment(clientName: "S. Côté", clientEmail: "s.cote@example.com", start: at(16, 30), durationMinutes: 60,
                        templateID: "preapproval", format: .video, videoURL: "https://meet.google.com/demo",
                        receivedDocuments: Array(pre.prefix(1)), notes: "First home in Laval, budget around $540,000.", isDemo: true),
            Appointment(clientName: "M. Tremblay", clientEmail: "m.tremblay@example.com", start: at(11, 0, dayOffset: 2), durationMinutes: 45,
                        templateID: "heloc", format: .phone, isDemo: true)
        ]
        appointments.forEach(context.insert)

        let yearAgo = Calendar.current.date(byAdding: .month, value: -1, to: today)
        let clients = [
            Client(name: "J. Martin", email: "j.martin@example.com", kycReviewDue: yearAgo, source: "Demo data"),
            Client(name: "R. Gagnon", email: "r.gagnon@example.com", preferredLanguage: "fr", source: "Demo data"),
            Client(name: "A. Nguyen", email: "a.nguyen@example.com", kycReviewDue: Calendar.current.date(byAdding: .month, value: 8, to: today), source: "Demo data"),
            Client(name: "S. Côté", email: "s.cote@example.com", preferredLanguage: "fr", source: "Demo data"),
            Client(name: "M. Tremblay", email: "m.tremblay@example.com", kycReviewDue: Calendar.current.date(byAdding: .month, value: 3, to: today), source: "Demo data")
        ]
        clients.forEach(context.insert)
        appointments.forEach { $0.linkClient(from: clients) }
        context.log("Demo data loaded", by: "System")
        try? context.save()
    }

    static func remove(from context: ModelContext) {
        try? context.delete(model: Appointment.self, where: #Predicate { $0.isDemo })
        try? context.delete(model: Client.self, where: #Predicate { $0.source == "Demo data" })
        context.log("Demo data removed", by: "System")
        try? context.save()
    }
}
