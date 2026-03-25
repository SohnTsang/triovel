import SwiftUI
import Auth

struct ProfileHeaderView: View {
    let user: User?

    var body: some View {
        HStack(spacing: 16) {
            // Avatar placeholder
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 56, height: 56)
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.headline)
                Text(user?.email ?? String(localized: "settings.no.email"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        if let metadata = user?.userMetadata,
           let name = metadata["full_name"]?.value as? String,
           !name.isEmpty {
            return name
        }
        return user?.email ?? String(localized: "settings.default.name")
    }
}
