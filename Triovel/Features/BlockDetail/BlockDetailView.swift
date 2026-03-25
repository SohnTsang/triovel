import SwiftUI

struct BlockDetailView: View {
    let blockId: String
    @EnvironmentObject private var appState: AppState
    @Environment(\.horizontalSizeClass) private var sizeClass
    @StateObject private var viewModel = BlockDetailViewModel()

    var body: some View {
        VStack(spacing: 0) {
            if let block = viewModel.block {
                BlockDetailHeaderView(
                    block: block,
                    canEdit: viewModel.canEditHeader,
                    isEditing: $viewModel.isEditingHeader,
                    editTitle: $viewModel.editTitle,
                    editLocation: $viewModel.editLocation,
                    onSave: { viewModel.saveHeaderEdits() }
                )

                Divider()

                // Unified memory stream — Phase 2
                ScrollView {
                    LazyVStack(spacing: 12) {
                        Text("block.detail.no.posts")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 40)
                    }
                    .padding()
                }

                Divider()

                // Composer area — Phase 2
                ComposerPlaceholderView()
            } else if viewModel.isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else if let error = viewModel.errorMessage {
                Spacer()
                Text(error)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: sizeClass == .regular ? 600 : .infinity)
        .frame(maxWidth: .infinity)
        .navigationTitle(viewModel.block?.title ?? "Block")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let userId = appState.currentUserId {
                await viewModel.load(blockId: blockId, userId: userId)
            }
        }
    }
}

/// Minimal composer shell — full implementation in Phase 2.
private struct ComposerPlaceholderView: View {
    var body: some View {
        HStack {
            Text("block.detail.composer.placeholder")
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding()
        .background(Color(.systemGray6))
    }
}
