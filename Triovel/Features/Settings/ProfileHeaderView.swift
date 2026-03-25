import SwiftUI
import Auth

struct ProfileHeaderView: View {
    let user: User?

    var body: some View {
        HStack(spacing: 16) {
            // 64pt avatar with initials on colored background
            AvatarView(
                initials: avatarInitials,
                userId: user?.id.uuidString ?? "default",
                size: 64
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(TypographyTokens.sectionHeader)
                    .foregroundStyle(ColorTokens.label)

                Text(user?.email ?? String(localized: "settings.no.email"))
                    .font(TypographyTokens.subheadline)
                    .foregroundStyle(ColorTokens.secondaryLabel)
            }
        }
        .padding(.vertical, 8)
    }

    private var displayName: String {
        if let metadata = user?.userMetadata,
           let name = metadata["full_name"]?.value as? String,
           !name.isEmpty {
            return name
        }
        return user?.email ?? String(localized: "settings.default.name")
    }

    private var avatarInitials: String {
        let name = displayName
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(name.prefix(1)).uppercased()
    }
}
