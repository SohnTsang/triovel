import SwiftUI

struct JoinTripView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var appState: AppState

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
                    .font(TypographyTokens.subheadline)
                    .foregroundStyle(ColorTokens.secondaryLabel)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                TriovelTextField(
                    placeholder: "trip.join.code.placeholder",
                    text: $inviteCode,
                    autocapitalization: .never
                )
                .focused($codeFocused)
                .padding(.horizontal, 24)

                if let error = errorMessage {
                    Text(error)
                        .font(TypographyTokens.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, 24)
                }

                Button {
                    joinTrip()
                } label: {
                    if isJoining {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("trip.join.button")
                    }
                }
                .buttonStyle(.triovelPrimary)
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
        .presentationDragIndicator(.visible)
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
