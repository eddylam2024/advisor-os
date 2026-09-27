# Advisor OS

A native Mac app for planning Canadian financial advice and lending appointments. It prepares the client brief, tracks the documents each client needs to bring, and drafts follow-ups and compliance notes that the advisor approves before anything is used.

Personal project for educational purposes. Not financial advice, and not affiliated with any employer. All demo data is fictional.

## What works in this version

- **Today:** appointments from the calendars already on the Mac (iCloud, Google, Exchange / Microsoft 365) through EventKit. There's nothing to sign in to. The appointment type and client name come from the event title, for example `Annual review – J. Martin`, and Teams, Zoom and Meet links are picked up from the event.
- **Document checklists:** Canadian templates for mortgage renewal, pre-approval, annual review, account opening and HELOC, in English and French.
- **Drafts:** brief, follow-up, reminder and compliance note. Apple's on-device model (Foundation Models) writes them when Apple Intelligence is on. Otherwise the app uses plain templates. Client data never leaves the Mac.
- **Approvals and audit trail:** nothing is used until it's approved. Approved emails open as drafts in the default mail app (Mail or Outlook) and are sent from the advisor's own address. Every action is logged.
- **Clients:** add clients by hand, or import and export CSV with common CRM column names.
- **Email a checklist:** from Templates, email a client their document list in English or French.
- **Menu bar:** shows the next appointment and any missing documents.

## Local only

Everything runs and is stored on the advisor's Mac: SwiftData for records, Apple's on-device model for drafts, and the Mac's own calendars and mail app. There's no Advisor OS server or cloud database, and nothing is sent anywhere except emails the advisor chooses to send. Every integration is free.

## Build and run

Requires macOS 26 on Apple silicon and Xcode 26. [XcodeGen](https://github.com/yonaskolb/XcodeGen) generates the Xcode project from `project.yml`.

```sh
brew install xcodegen
make run      # generate the project, build, and open the app
make test     # run the unit tests
```

Or run `make project` and open `AdvisorOS.xcodeproj` in Xcode.

The first build runs `scripts/make-signing-cert.sh`, which adds a self-signed "Advisor OS Local Signing" identity to your login keychain. Every build then has the same signature, so macOS remembers Calendar permission. It isn't an Apple certificate. Remove it in Keychain Access any time.

### Share a .dmg

```sh
make dmg      # dist/AdvisorOS-<version>.dmg
```

The .dmg isn't notarized by Apple, so the first time it's opened on another Mac, macOS blocks it. The note inside the .dmg explains the one-time fix: System Settings › Privacy & Security › Open Anyway. Notarizing removes that step and needs the Apple Developer Program (US$99/year).

## Project layout

```
AdvisorOS/
  App/        App entry point, window and menu bar extra
  Models/     SwiftData models and the Canadian appointment templates
  Services/   Calendar (EventKit), drafting (Foundation Models), mail drafts, CSV, demo data
  Design/     Tokens and components from the DesignCode UI kit, on native Liquid Glass
  Views/      Today, Approvals, Clients, Templates, Booking page, Connections, Settings
AdvisorOSTests/  Template matching, title parsing, CSV and mailto tests (Swift Testing)
scripts/make-icon.swift  Generates the app icon
```

## Next steps

1. **Client booking, run from this Mac:** clients pick a time and send documents with no cloud server. See "Local only" below.
2. **Notarized distribution:** Developer ID signing and notarization so the .dmg opens without warnings, plus Sparkle for updates. Needs the Apple Developer Program (US$99/year).
3. Microsoft 365, Google and Zoom sign-in for automatic video links. All are free APIs.
4. Webhooks so firms can connect their own CRM.
