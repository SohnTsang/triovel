import Foundation
import PowerSync

/// CRUD for block_documents in local PowerSync SQLite.
/// Upload/download handled separately via DocumentFileManager.
final class BlockDocumentRepository: @unchecked Sendable {
    private var db: PowerSyncDatabaseProtocol { SyncManager.shared.db }

    // MARK: - Create

    func createDocument(
        id: String? = nil,
        blockId: String,
        userId: String,
        fileName: String,
        fileType: DocumentFileType,
        fileSize: Int?
    ) async throws -> BlockDocument {
        let docId = id ?? UUID().uuidString.lowercased()
        let now = Self.isoString(from: Date())

        try await db.execute(
            sql: """
                INSERT INTO block_documents (id, block_id, user_id, file_name, file_type, upload_status, file_size, created_at)
                VALUES (?, ?, ?, ?, ?, 'queued', ?, ?)
                """,
            parameters: [docId, blockId, userId, fileName, fileType.rawValue, fileSize, now]
        )

        return BlockDocument(
            id: docId,
            blockId: blockId,
            userId: userId,
            fileName: fileName,
            fileType: fileType,
            storagePath: nil,
            uploadStatus: .queued,
            fileSize: fileSize,
            createdAt: Date()
        )
    }

    // MARK: - Update

    func updateUploadStatus(docId: String, status: UploadStatus) async throws {
        try await db.execute(
            sql: "UPDATE block_documents SET upload_status = ? WHERE id = ?",
            parameters: [status.rawValue, docId]
        )
    }

    func updateStoragePath(docId: String, storagePath: String) async throws {
        try await db.execute(
            sql: "UPDATE block_documents SET storage_path = ?, upload_status = 'uploaded' WHERE id = ?",
            parameters: [storagePath, docId]
        )
    }

    // MARK: - Fetch

    func fetchDocuments(blockId: String) async throws -> [BlockDocument] {
        try await db.getAll(
            sql: "SELECT * FROM block_documents WHERE block_id = ? ORDER BY created_at ASC",
            parameters: [blockId],
            mapper: Self.mapper
        )
    }

    /// Reactive stream of documents for a block.
    func watchDocuments(blockId: String) throws -> AsyncThrowingStream<[BlockDocument], Error> {
        try db.watch(
            sql: "SELECT * FROM block_documents WHERE block_id = ? ORDER BY created_at ASC",
            parameters: [blockId],
            mapper: Self.mapper
        )
    }

    // MARK: - Delete

    func deleteDocument(docId: String) async throws {
        try await db.execute(
            sql: "DELETE FROM block_documents WHERE id = ?",
            parameters: [docId]
        )
    }

    // MARK: - Mapper

    static let mapper: @Sendable (SqlCursor) throws -> BlockDocument = { cursor in
        let createdAtStr = try cursor.getString(name: "created_at")
        return BlockDocument(
            id: try cursor.getString(name: "id"),
            blockId: try cursor.getString(name: "block_id"),
            userId: try cursor.getString(name: "user_id"),
            fileName: try cursor.getString(name: "file_name"),
            fileType: DocumentFileType(rawValue: try cursor.getString(name: "file_type")) ?? .pdf,
            storagePath: try cursor.getStringOptional(name: "storage_path"),
            uploadStatus: UploadStatus(rawValue: try cursor.getString(name: "upload_status")) ?? .queued,
            fileSize: try cursor.getIntOptional(name: "file_size"),
            createdAt: parseDocISO(createdAtStr)
        )
    }

    private static func isoString(from date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}

private func parseDocISO(_ str: String) -> Date {
    let f = ISO8601DateFormatter()
    f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let d = f.date(from: str) { return d }
    f.formatOptions = [.withInternetDateTime]
    return f.date(from: str) ?? Date()
}
