import Foundation
import UIKit
import CoreGraphics
import Supabase

/// Handles local file storage and Supabase Storage upload/download for block documents.
/// Documents are copied to a local directory on pick, uploaded when online,
/// and downloaded on-demand for viewing.
///
/// Local path: <appDocuments>/Documents/<docId>/<fileName>
/// Remote path: trips/<tripId>/docs/<docId>/<fileName>
actor DocumentFileManager {
    static let shared = DocumentFileManager()

    private let client = SupabaseConfig.client
    private let repository = BlockDocumentRepository()
    private let maxFileSize = 10 * 1024 * 1024 // 10 MB

    // MARK: - Local Directory

    private func localDir(for docId: String) -> URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("Documents/\(docId)", isDirectory: true)
    }

    private func localPath(for docId: String, fileName: String) -> URL {
        localDir(for: docId).appendingPathComponent(fileName)
    }

    // MARK: - Import (copy picked file to local storage)

    /// Copy a file from the picker URL to local app storage.
    /// Compresses images (JPEG target 1.5 MB) and PDFs (re-render to strip bloat).
    /// Returns the file size in bytes. Throws if file is too large after compression.
    func importFile(from sourceURL: URL, docId: String, fileName: String) throws -> Int {
        let dir = localDir(for: docId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let destination = dir.appendingPathComponent(fileName)

        // Access security-scoped resource (file picker URLs require this)
        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }

        var data = try Data(contentsOf: sourceURL)
        let ext = (fileName as NSString).pathExtension.lowercased()

        // Compress images
        if ["jpg", "jpeg", "png", "heic", "heif"].contains(ext), let image = UIImage(data: data) {
            data = Self.compressImage(image, targetBytes: 1_500_000)
        }

        // Compress PDFs by re-rendering pages (strips previews, recompresses images)
        if ext == "pdf" && data.count > 2_000_000 {
            if let compressed = Self.compressPDF(data: data) {
                data = compressed
            }
        }

        guard data.count <= maxFileSize else {
            throw DocumentError.fileTooLarge
        }

        try data.write(to: destination)
        return data.count
    }

    // MARK: - Compression

    private static func compressImage(_ image: UIImage, targetBytes: Int) -> Data {
        var quality: CGFloat = 0.8
        var data = image.jpegData(compressionQuality: quality) ?? Data()
        while data.count > targetBytes && quality > 0.1 {
            quality -= 0.1
            data = image.jpegData(compressionQuality: quality) ?? data
        }
        return data
    }

    private static func compressPDF(data: Data) -> Data? {
        guard let provider = CGDataProvider(data: data as CFData),
              let pdf = CGPDFDocument(provider) else { return nil }

        let pageCount = pdf.numberOfPages
        guard pageCount > 0 else { return nil }

        let mutableData = NSMutableData()
        guard let consumer = CGDataConsumer(data: mutableData),
              let context = CGContext(consumer: consumer, mediaBox: nil, nil) else { return nil }

        for i in 1...pageCount {
            guard let page = pdf.page(at: i) else { continue }
            var mediaBox = page.getBoxRect(.mediaBox)
            context.beginPage(mediaBox: &mediaBox)
            context.drawPDFPage(page)
            context.endPage()
        }
        context.closePDF()

        let result = mutableData as Data
        // Only use compressed version if it's actually smaller
        return result.count < data.count ? result : nil
    }

    // MARK: - Upload

    /// Upload a local document to Supabase Storage.
    /// Updates the DB row with storage_path on success.
    func upload(docId: String, fileName: String, tripId: String) async throws {
        let localFile = localPath(for: docId, fileName: fileName)

        guard FileManager.default.fileExists(atPath: localFile.path) else {
            throw DocumentError.localFileNotFound
        }

        try await repository.updateUploadStatus(docId: docId, status: .uploading)

        let data = try Data(contentsOf: localFile)
        // Use docId + extension as remote filename to avoid non-ASCII character issues
        let ext = (fileName as NSString).pathExtension
        let safeFileName = "\(docId).\(ext)"
        let remotePath = "trips/\(tripId)/docs/\(docId)/\(safeFileName)"
        let contentType = ext.lowercased() == "pdf" ? "application/pdf" : "image/jpeg"

        do {
            try await client.storage.from("documents").upload(
                remotePath,
                data: data,
                options: .init(contentType: contentType, upsert: true)
            )
            try await repository.updateStoragePath(docId: docId, storagePath: remotePath)
            print("[DocManager] ✓ Uploaded: \(fileName)")
        } catch {
            try await repository.updateUploadStatus(docId: docId, status: .failed)
            print("[DocManager] ❌ Upload failed: \(error)")
            throw error
        }
    }

    // MARK: - Download (for viewing remote documents)

    /// Download a document from Supabase Storage to local cache.
    /// Returns the local file URL for QuickLook / preview.
    func download(docId: String, fileName: String, storagePath: String) async throws -> URL {
        let localFile = localPath(for: docId, fileName: fileName)

        // Already cached locally
        if FileManager.default.fileExists(atPath: localFile.path) {
            return localFile
        }

        let dir = localDir(for: docId)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let data = try await client.storage.from("documents").download(path: storagePath)
        try data.write(to: localFile)
        print("[DocManager] ✓ Downloaded: \(fileName)")
        return localFile
    }

    // MARK: - Delete local files

    func deleteLocalFiles(docId: String) {
        let dir = localDir(for: docId)
        try? FileManager.default.removeItem(at: dir)
    }

    // MARK: - Delete remote + local

    func deleteDocument(docId: String, storagePath: String?) async {
        // Remote
        if let path = storagePath {
            do {
                try await client.storage.from("documents").remove(paths: [path])
            } catch {
                print("[DocManager] ⚠️ Remote delete failed: \(error)")
            }
        }
        // Local
        deleteLocalFiles(docId: docId)
    }

    // MARK: - Retry failed upload

    func retryUpload(docId: String, fileName: String, tripId: String) async {
        do {
            try await repository.updateUploadStatus(docId: docId, status: .queued)
            try await upload(docId: docId, fileName: fileName, tripId: tripId)
        } catch {
            print("[DocManager] ❌ Retry failed: \(error)")
        }
    }

    // MARK: - Resume pending uploads

    func resumePendingUploads(blockId: String, tripId: String) async {
        do {
            let docs = try await repository.fetchDocuments(blockId: blockId)
            let pending = docs.filter { $0.uploadStatus == .queued || $0.uploadStatus == .uploading }
            for doc in pending {
                try await upload(docId: doc.id, fileName: doc.fileName, tripId: tripId)
            }
        } catch {
            print("[DocManager] ⚠️ Resume pending failed: \(error)")
        }
    }
}

// MARK: - Errors

enum DocumentError: LocalizedError {
    case fileTooLarge
    case localFileNotFound
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .fileTooLarge: return String(localized: "document.error.too.large")
        case .localFileNotFound: return String(localized: "document.error.not.found")
        case .unsupportedFormat: return String(localized: "document.error.unsupported")
        }
    }
}
