import Foundation
import PowerSync

/// CRUD for bills and bill_shares in local PowerSync SQLite.
/// Amounts are always integers in smallest currency unit (e.g. cents).
final class BillRepository: @unchecked Sendable {
    private var db: PowerSyncDatabaseProtocol { SyncManager.shared.db }

    // MARK: - Create Bill + Shares (local-first)

    /// Creates a bill and its equal-split shares in a single transaction.
    func createBill(
        blockId: String,
        tripId: String,
        amount: Int,
        currency: String,
        payerId: String,
        memberIds: [String]
    ) async throws -> Bill {
        let billId = UUID().uuidString.lowercased()
        let now = Self.isoString(from: Date())
        let shareAmount = amount / max(memberIds.count, 1)

        try await db.writeTransaction { tx in
            try tx.execute(
                sql: """
                    INSERT INTO bills (id, block_id, trip_id, amount, currency, payer_id, created_at)
                    VALUES (?, ?, ?, ?, ?, ?, ?)
                    """,
                parameters: [billId, blockId, tripId, amount, currency, payerId, now]
            )

            for memberId in memberIds {
                let shareId = UUID().uuidString.lowercased()
                try tx.execute(
                    sql: """
                        INSERT INTO bill_shares (id, bill_id, user_id, share_amount, trip_id)
                        VALUES (?, ?, ?, ?, ?)
                        """,
                    parameters: [shareId, billId, memberId, shareAmount, tripId]
                )
            }
        }

        print("[BillRepo] Created bill \(billId): \(amount) \(currency), split \(memberIds.count) ways")
        BetaAnalytics.trackBillCreated()

        return Bill(
            id: billId,
            blockId: blockId,
            tripId: tripId,
            amount: amount,
            currency: currency,
            payerId: payerId,
            createdAt: Date()
        )
    }

    // MARK: - Fetch Bills for Block

    func fetchBillsForBlock(blockId: String) async throws -> [Bill] {
        try await db.getAll(
            sql: "SELECT * FROM bills WHERE block_id = ? ORDER BY created_at ASC",
            parameters: [blockId],
            mapper: Self.billMapper
        )
    }

    /// Reactive stream of bills for a block.
    func watchBillsForBlock(blockId: String) throws -> AsyncThrowingStream<[Bill], Error> {
        try db.watch(
            sql: "SELECT * FROM bills WHERE block_id = ? ORDER BY created_at ASC",
            parameters: [blockId],
            mapper: Self.billMapper
        )
    }

    // MARK: - Fetch Bills for Trip

    func fetchBillsForTrip(tripId: String) async throws -> [Bill] {
        try await db.getAll(
            sql: "SELECT * FROM bills WHERE trip_id = ? ORDER BY created_at ASC",
            parameters: [tripId],
            mapper: Self.billMapper
        )
    }

    /// Fetch only group block bills (one-shot, for reload after payment changes).
    func fetchGroupBillsForTrip(tripId: String) async throws -> [Bill] {
        try await db.getAll(
            sql: """
                SELECT b.* FROM bills b
                JOIN blocks bl ON b.block_id = bl.id
                WHERE b.trip_id = ? AND bl.context = 'group'
                ORDER BY b.created_at ASC
                """,
            parameters: [tripId],
            mapper: Self.billMapper
        )
    }

    /// Watch only group block bills (personal block bills excluded from summary).
    func watchGroupBillsForTrip(tripId: String) throws -> AsyncThrowingStream<[Bill], Error> {
        try db.watch(
            sql: """
                SELECT b.* FROM bills b
                JOIN blocks bl ON b.block_id = bl.id
                WHERE b.trip_id = ? AND bl.context = 'group'
                ORDER BY b.created_at ASC
                """,
            parameters: [tripId],
            mapper: Self.billMapper
        )
    }

    func watchBillsForTrip(tripId: String) throws -> AsyncThrowingStream<[Bill], Error> {
        try db.watch(
            sql: "SELECT * FROM bills WHERE trip_id = ? ORDER BY created_at ASC",
            parameters: [tripId],
            mapper: Self.billMapper
        )
    }

    // MARK: - Fetch Shares

    func fetchSharesForBill(billId: String) async throws -> [BillShare] {
        try await db.getAll(
            sql: "SELECT * FROM bill_shares WHERE bill_id = ?",
            parameters: [billId],
            mapper: Self.shareMapper
        )
    }

    func fetchAllSharesForTrip(tripId: String) async throws -> [BillShare] {
        try await db.getAll(
            sql: "SELECT * FROM bill_shares WHERE trip_id = ?",
            parameters: [tripId],
            mapper: Self.shareMapper
        )
    }

    // MARK: - Delete Bill

    func deleteBill(billId: String) async throws {
        // bill_shares cascade-deleted on Supabase; delete locally too
        try await db.writeTransaction { tx in
            try tx.execute(sql: "DELETE FROM bill_shares WHERE bill_id = ?", parameters: [billId])
            try tx.execute(sql: "DELETE FROM bills WHERE id = ?", parameters: [billId])
        }
        print("[BillRepo] Deleted bill: \(billId)")
    }

    // MARK: - Mappers

    static let billMapper: @Sendable (SqlCursor) throws -> Bill = { cursor in
        Bill(
            id: try cursor.getString(name: "id"),
            blockId: try cursor.getString(name: "block_id"),
            tripId: try cursor.getString(name: "trip_id"),
            amount: try cursor.getInt(name: "amount"),
            currency: try cursor.getString(name: "currency"),
            payerId: try cursor.getString(name: "payer_id"),
            createdAt: parseISO(try cursor.getString(name: "created_at"))
        )
    }

    static let shareMapper: @Sendable (SqlCursor) throws -> BillShare = { cursor in
        BillShare(
            id: try cursor.getString(name: "id"),
            billId: try cursor.getString(name: "bill_id"),
            userId: try cursor.getString(name: "user_id"),
            shareAmount: try cursor.getInt(name: "share_amount")
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
