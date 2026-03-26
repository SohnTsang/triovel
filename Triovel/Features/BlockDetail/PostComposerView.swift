import SwiftUI

/// Composer at the bottom of Block Detail for creating posts.
/// Every new draft starts Shared — resets after send/cancel/leave per examples.md.
struct PostComposerView: View {
    let onSend: (String, PostVisibility) -> Void
    let isSending: Bool

    @State private var text = ""
    @State private var visibility: PostVisibility = .shared
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Visibility toggle
            Picker("Visibility", selection: $visibility) {
                Text("post.visibility.shared").tag(PostVisibility.shared)
                Text("post.visibility.just.me").tag(PostVisibility.private)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Input row
            HStack(alignment: .bottom, spacing: 12) {
                TextField(
                    visibility == .shared
                        ? String(localized: "post.composer.placeholder.shared")
                        : String(localized: "post.composer.placeholder.private"),
                    text: $text,
                    axis: .vertical
                )
                .lineLimit(1...6)
                .focused($isFocused)
                .textFieldStyle(.plain)

                // Send button — fixed frame, never resizes
                Button {
                    send()
                } label: {
                    Group {
                        if isSending {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSending)
                .tint(Color.accentColor)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let currentVisibility = visibility
        onSend(trimmed, currentVisibility)

        // Reset per examples.md: every new draft starts Shared
        text = ""
        visibility = .shared
        isFocused = false
    }
}
