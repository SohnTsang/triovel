import Foundation
import Observation

/// Lightweight dependency container for Phase 1.
/// Services are created here and passed through the environment.
@Observable
@MainActor
final class DependencyContainer {
    let authService: AuthService

    init(authService: AuthService) {
        self.authService = authService
    }
}
