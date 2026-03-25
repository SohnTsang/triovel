import SwiftUI

struct JoinTripView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appState: AppState

    /// Called with the joined trip ID on success.
    private let onTripJoined: ((String) -> Void)?

    init(onTripJoined: ((String) -> Void)? = nil) {
        self.onTripJoined = onTripJoined
    }

    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @FocusState private var codeFocused: Bool

    private let tripRepository = TripRepository()

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter the invite code shared by your trip organizer.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                TextField("Invite code", text: $inviteCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($codeFocused)
                    .padding()
                    .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 24)

                if let error = errorMessage {
                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }

                Button {
                    joinTrip()
                } label: {
                    if isJoining {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Join Trip")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty || isJoining)
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle("Join a Trip")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isJoining)
                }
            }
            .interactiveDismissDisabled(isJoining)
            .onAppear { codeFocused = true }
        }
    }

    private func joinTrip() {
        let code = inviteCode.trimmingCharacters(in: .whitespaces)
        guard !code.isEmpty else { return }
        guard let userId = appState.currentUserId else { return }

        isJoining = true
        errorMessage = nil

        Task {
            do {
                let tripId = try await tripRepository.joinTrip(
                    inviteCode: code,
                    userId: userId
                )

                dismiss()
                try? await Task.sleep(for: .milliseconds(300))
                onTripJoined?(tripId)
            } catch let error as TripRepositoryError {
                errorMessage = error.localizedDescription
                isJoining = false
            } catch {
                errorMessage = "Could not join trip. Please check the code and try again."
                isJoining = false
            }
        }
    }
}
