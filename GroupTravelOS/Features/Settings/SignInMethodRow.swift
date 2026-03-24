import SwiftUI
import Auth

struct SignInMethodRow: View {
    let user: User?

    var body: some View {
        HStack {
            Label("Sign-in method", systemImage: iconName)
            Spacer()
            Text(methodLabel)
                .foregroundStyle(.secondary)
        }
    }

    private var methodLabel: String {
        guard let provider = user?.appMetadata["provider"]?.value as? String else {
            return "Unknown"
        }
        switch provider {
        case "apple":
            return "Apple"
        case "email":
            return "Email"
        default:
            return provider.capitalized
        }
    }

    private var iconName: String {
        guard let provider = user?.appMetadata["provider"]?.value as? String else {
            return "person.badge.key"
        }
        switch provider {
        case "apple":
            return "apple.logo"
        case "email":
            return "envelope"
        default:
            return "person.badge.key"
        }
    }
}
