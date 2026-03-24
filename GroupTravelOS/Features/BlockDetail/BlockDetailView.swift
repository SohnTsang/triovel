import SwiftUI

struct BlockDetailView: View {
    let blockId: String

    var body: some View {
        VStack(spacing: 0) {
            // Header section — will show title, context chip, time, location
            BlockDetailHeaderView()

            Divider()

            // Unified memory stream — posts, bills, media states
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Placeholder for stream items
                    Text("No posts yet")
                        .foregroundStyle(.secondary)
                        .padding(.top, 40)
                }
                .padding()
            }

            Divider()

            // Composer area — Phase 2
            ComposerPlaceholderView()
        }
        .navigationTitle("Block Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BlockDetailHeaderView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Block Title")
                .font(.title2.weight(.semibold))
            Text("Group")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color(.systemGray6), in: Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}

/// Minimal composer shell — full implementation in Phase 2.
private struct ComposerPlaceholderView: View {
    var body: some View {
        HStack {
            Text("Add a memory…")
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
    }
}
