import Foundation

/// Lightweight dependency container for Phase 1.
/// Services are created here and passed through the environment.
@MainActor
final class DependencyContainer: ObservableObject {
    let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }
}
