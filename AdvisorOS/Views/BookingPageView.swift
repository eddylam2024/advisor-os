import SwiftUI

/// The client-facing web booking page is the next piece to build (see README).
/// Until it exists, advisors share checklists by email from Templates.
struct BookingPageView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.gapLarge) {
                VStack(alignment: .leading, spacing: Theme.gap) {
                    HStack {
                        Text("Your booking page").font(.title2.weight(.semibold))
                        Spacer()
                        Pill(text: "Coming next", tint: Theme.warn)
                    }
                    Text("Clients will pick an appointment type and a time in English or French, and send their documents. It runs from this Mac: no cloud server, no account for clients, and nothing stored outside your computer. New bookings will appear in Today and Clients.")
                        .foregroundStyle(.secondary)
                }
                .glassCard()

                VStack(alignment: .leading, spacing: Theme.gap) {
                    SectionLabel("Works today")
                    Label("Email any client the checklist for their appointment, in English or French, from Templates.", systemImage: "envelope")
                    Label("Book in your usual calendar. Put the type in the title, like \"Annual review – J. Martin\", and Advisor OS picks the right template.", systemImage: "calendar")
                    Label("Video links from Teams, Zoom or Meet in the event are picked up automatically.", systemImage: "video")
                }
                .glassCard()
            }
            .padding(Theme.paddingLarge)
        }
    }
}
