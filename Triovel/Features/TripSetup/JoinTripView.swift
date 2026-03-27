import SwiftUI

struct JoinTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(AppState.self) private var appState

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
                Text("trip.join.instructions")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                TextField(String(localized: "trip.join.code.placeholder"), text: $inviteCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($codeFocused)
                    .onChange(of: inviteCode) { _, newValue in
                        if newValue.count > 50 { inviteCode = String(newValue.prefix(50)) }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 14)
                    .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
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
                    Group {
                        if isJoining {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Text("trip.join.button")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .disabled(inviteCode.trimmingCharacters(in: .whitespaces).isEmpty || isJoining)
                .padding(.horizontal, 24)

                Spacer()
            }
            .navigationTitle(String(localized: "trip.join.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .disabled(isJoining)
                }
            }
            .interactiveDismissDisabled(isJoining)
            .onAppear { codeFocused = true }
        }
        .presentationDetents(sizeClass == .regular ? [.medium, .large] : [.medium])
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
                errorMessage = String(localized: "trip.join.error")
                isJoining = false
            }
        }
    }
}
