import SwiftUI

/// Tokens from the DesignCode UI kit (Figma file bKv9UGnndSEsIvP4VBETOt), mapped onto native macOS materials.
enum Theme {
    static let radiusButton: CGFloat = 8     // Button/corner-radius
    static let radiusBox: CGFloat = 10       // Container/corner-radius
    static let radiusCard: CGFloat = 14
    static let padding: CGFloat = 10         // Container/padding
    static let paddingLarge: CGFloat = 20    // Container/padding-large
    static let gap: CGFloat = 10             // Container/gap
    static let gapLarge: CGFloat = 20        // Content/gap-extra-large

    static let good = Color.green
    static let warn = Color.orange
    static let avatarColors: [Color] = [
        Color(red: 0.29, green: 0.42, blue: 0.90), Color(red: 0.88, green: 0.45, blue: 0.36),
        Color(red: 0.55, green: 0.42, blue: 0.91), Color(red: 0.12, green: 0.62, blue: 0.54),
        Color(red: 0.79, green: 0.54, blue: 0.17)
    ]
}

/// The kit's blue / coral / lavender glow, kept soft so content stays readable.
struct KitBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Circle().fill(Color(red: 0.29, green: 0.42, blue: 0.90))
                    .frame(width: geo.size.width * 0.9).offset(x: geo.size.width * 0.1, y: -geo.size.height * 0.55)
                Circle().fill(Color(red: 0.94, green: 0.55, blue: 0.45))
                    .frame(width: geo.size.width * 0.45).offset(x: -geo.size.width * 0.4, y: geo.size.height * 0.25)
                Circle().fill(Color(red: 0.72, green: 0.65, blue: 0.95))
                    .frame(width: geo.size.width * 0.5).offset(x: geo.size.width * 0.45, y: geo.size.height * 0.05)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .blur(radius: 120)
            .opacity(scheme == .dark ? 0.35 : 0.28)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

struct GlassCard: ViewModifier {
    var padding: CGFloat = Theme.paddingLarge

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: Theme.radiusCard))
    }
}

extension View {
    func glassCard(padding: CGFloat = Theme.paddingLarge) -> some View { modifier(GlassCard(padding: padding)) }
}

struct Pill: View {
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .foregroundStyle(tint == .secondary ? Color.secondary : tint)
            .background(tint.opacity(0.14), in: Capsule())
    }
}

struct SectionLabel: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .tracking(0.6)
            .foregroundStyle(.secondary)
    }
}

struct Avatar: View {
    let name: String
    var size: CGFloat = 34

    private var initials: String {
        name.split(whereSeparator: { $0 == " " || $0 == "." })
            .compactMap(\.first).prefix(2).map(String.init).joined().uppercased()
    }

    private var color: Color {
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return Theme.avatarColors[sum % Theme.avatarColors.count]
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.36, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color, in: Circle())
    }
}

struct EmptyStateView: View {
    let title: String
    let systemImage: String
    let message: String

    var body: some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(message))
    }
}
