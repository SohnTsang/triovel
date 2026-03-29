import Foundation
import PowerSync

/// CRUD for payments in local PowerSync SQLite.
/// Payments are trip-level (not block-level) repayments between two people.
final class PaymentRepository {
    private var db: PowerSyncDatabaseProtocol { SyncManager.shared.db }

    // MARK: - Create Payment

    func createPayment(
        tripId: String,
        payerId: String,
        receiverId: String,
        amount: Int,
        currency: String,
        note: String?
    ) async throws -> Payment {
        let paymentId = UUID().uuidString.lowercased()
        let now = Self.isoString(from: Date())

        try await db.execute(
            sql: """
                INSERT INTO payments (id, trip_id, payer_id, receiver_id, amount, currency, note, created_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
            parameters: [paymentId, tripId, payerId, receiverId, amount, currency, note, now]
        )

        print("[PaymentRepo] Created payment \(paymentId): \(amount) \(currency)")
        BetaAnalytics.trackPaymentRecorded()

        return Payment(
            id: paymentId,
            tripId: tripId,
            payerId: payerId,
            receiverId: receiverId,
            amount: amount,
            currency: currency,
            note: note,
            createdAt: Date()
        )
    }

    // MARK: - Fetch

    func fetchPaymentsForTrip(tripId: String) async throws -> [Payment] {
        try await db.getAll(
            sql: "SELECT * FROM payments WHERE trip_id = ? ORDER BY created_at ASC",
            parameters: [tripId],
            mapper: Self.paymentMapper
        )
    }

    func watchPaymentsForTrip(tripId: String) throws -> AsyncThrowingStream<[Payment], Error> {
        try db.watch(
            sql: "SELECT * FROM payments WHERE trip_id = ? ORDER BY created_at ASC",
            parameters: [tripId],
            mapper: Self.paymentMapper
        )
    }

    // MARK: - Delete

    func deletePayment(paymentId: String) async throws {
        try await db.execute(
            sql: "DELETE FROM payments WHERE id = ?",
            parameters: [paymentId]
        )
        print("[PaymentRepo] Deleted payment: \(paymentId)")
    }

    // MARK: - Mapper

    static let paymentMapper: @Sendable (SqlCursor) throws -> Payment = { cursor in
        Payment(
            id: try cursor.getString(name: "id"),
            tripId: try cursor.getString(name: "trip_id"),
            payerId: try cursor.getString(name: "payer_id"),
            receiverId: try cursor.getString(name: "receiver_id"),
            amount: try cursor.getInt(name: "amount"),
            currency: try cursor.getString(name: "currency"),
            note: try cursor.getStringOptional(name: "note"),
            createdAt: parseISO(try cursor.getString(name: "created_at"))
        )
    }

    private static func isoString(from date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}

private func parseISO(_ str: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: str) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: str) ?? Date()
}
