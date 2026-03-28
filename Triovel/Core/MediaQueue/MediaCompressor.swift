import UIKit
import AVFoundation

/// Compresses photos and videos on background threads.
/// Never rejects — always compresses harder if needed.
enum MediaCompressor {

    // MARK: - Photo Compression

    /// Compress photo to target byte size using iterative JPEG quality reduction.
    /// Runs on background thread. Never rejects — compresses harder if needed.
    static func compressPhoto(_ imageData: Data, targetBytes: Int = 1_500_000) async throws -> Data {
        try await Task.detached(priority: .utility) {
            guard let image = UIImage(data: imageData) else {
                throw MediaCompressionError.invalidImage
            }
            return try compressImage(image, targetBytes: targetBytes)
        }.value
    }

    /// Compress UIImage to target byte size.
    static func compressPhoto(_ image: UIImage, targetBytes: Int = 1_500_000) async throws -> Data {
        try await Task.detached(priority: .utility) {
            try compressImage(image, targetBytes: targetBytes)
        }.value
    }

    /// Generate thumbnail from image data.
    static func generateThumbnail(from imageData: Data, maxDimension: CGFloat = 400) -> UIImage? {
        guard let image = UIImage(data: imageData) else { return nil }
        return downsample(image, maxDimension: maxDimension)
    }

    /// Generate thumbnail from UIImage.
    static func generateThumbnail(from image: UIImage, maxDimension: CGFloat = 400) -> UIImage? {
        downsample(image, maxDimension: maxDimension)
    }

    // MARK: - Video

    /// Transcode video to H.264 1080p 30fps, targeting byte size and max duration.
    /// Returns URL to the transcoded temp file.
    static func transcodeVideo(
        sourceURL: URL,
        maxDuration: TimeInterval = 60,
        targetPreset: String = AVAssetExportPresetHighestQuality
    ) async throws -> URL {
        try await Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: sourceURL)
            let duration = try await asset.load(.duration)
            let durationSeconds = CMTimeGetSeconds(duration)

            guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080) else {
                throw MediaCompressionError.transcodeUnavailable
            }

            let outputURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString + ".mp4")

            session.outputURL = outputURL
            session.outputFileType = .mp4
            session.shouldOptimizeForNetworkUse = true

            // Trim to max duration if needed
            if durationSeconds > maxDuration {
                let endTime = CMTime(seconds: maxDuration, preferredTimescale: 600)
                session.timeRange = CMTimeRange(start: .zero, end: endTime)
            }

            await session.export()

            guard session.status == .completed else {
                throw MediaCompressionError.transcodeFailed(session.error?.localizedDescription ?? "Unknown error")
            }

            return outputURL
        }.value
    }

    /// Generate thumbnail from video at the given time.
    static func generateVideoThumbnail(from url: URL, at time: CMTime = CMTime(seconds: 0.5, preferredTimescale: 600)) -> UIImage? {
        let asset = AVURLAsset(url: url)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 400, height: 400)

        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    /// Get video duration in seconds.
    static func videoDuration(url: URL) async -> TimeInterval? {
        let asset = AVURLAsset(url: url)
        guard let duration = try? await asset.load(.duration) else { return nil }
        return CMTimeGetSeconds(duration)
    }

    // MARK: - Private

    private static func compressImage(_ image: UIImage, targetBytes: Int) throws -> Data {
        // First try at 0.8 quality
        var quality: CGFloat = 0.8
        var data = image.jpegData(compressionQuality: quality) ?? Data()

        if data.count <= targetBytes {
            return data
        }

        // Binary search for optimal quality
        var low: CGFloat = 0.05
        var high: CGFloat = 0.8

        for _ in 0..<6 {
            quality = (low + high) / 2
            data = image.jpegData(compressionQuality: quality) ?? Data()

            if data.count > targetBytes {
                high = quality
            } else {
                low = quality
            }
        }

        // If still too large, downscale the image
        if data.count > targetBytes {
            let scale = sqrt(Double(targetBytes) / Double(data.count))
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            let renderer = UIGraphicsImageRenderer(size: newSize)
            let resized = renderer.image { _ in
                image.draw(in: CGRect(origin: .zero, size: newSize))
            }
            data = resized.jpegData(compressionQuality: 0.7) ?? data
        }

        return data
    }

    private static func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let scale = min(maxDimension / max(size.width, size.height), 1.0)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Error

enum MediaCompressionError: LocalizedError {
    case invalidImage
    case transcodeUnavailable
    case transcodeFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidImage: return "Invalid image data."
        case .transcodeUnavailable: return "Video transcoding is not available."
        case .transcodeFailed(let reason): return "Video transcoding failed: \(reason)"
        }
    }
}
