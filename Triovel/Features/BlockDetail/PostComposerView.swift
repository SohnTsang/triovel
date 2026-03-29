import SwiftUI
import PhotosUI

/// Composer at the bottom of Block Detail for creating posts.
/// Every new draft starts Shared — resets after send/cancel/leave per examples.md.
struct PostComposerView: View {
    let onSend: (String, PostVisibility, [MediaItem]) -> Void
    let isSending: Bool

    @State private var text = ""
    @State private var visibility: PostVisibility = .shared
    @State private var mediaItems: [MediaItem] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var isProcessingMedia = false
    @State private var processingCount = 0
    @FocusState private var isFocused: Bool

    private var canSend: Bool {
        let hasText = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMedia = !mediaItems.isEmpty
        return (hasText || hasMedia) && !isSending && !isProcessingMedia
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            // Visibility toggle
            Picker("Visibility", selection: $visibility) {
                Text("post.visibility.shared").tag(PostVisibility.shared)
                Text("post.visibility.just.me").tag(PostVisibility.private)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Media attachment preview (shows loaded items + loading skeletons)
            if !mediaItems.isEmpty || processingCount > 0 {
                MediaAttachmentPreview(
                    items: mediaItems,
                    processingCount: processingCount
                ) { id in
                    mediaItems.removeAll { $0.id == id }
                }
            }

            // Input row
            HStack(alignment: .bottom, spacing: 8) {
                // Action buttons
                HStack(spacing: 4) {
                    // Camera
                    Button {
                        Task {
                            let granted = await CameraPickerView.requestPermission()
                            if granted { showCamera = true }
                        }
                    } label: {
                        Image(systemName: "camera")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)

                    // Photo library
                    PhotosPicker(
                        selection: $selectedPhotos,
                        maxSelectionCount: 10,
                        matching: .any(of: [.images, .videos])
                    ) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 32, height: 32)
                }

                TextField(
                    visibility == .shared
                        ? String(localized: "post.composer.placeholder.shared")
                        : String(localized: "post.composer.placeholder.private"),
                    text: $text,
                    axis: .vertical
                )
                .lineLimit(1...6)
                .focused($isFocused)
                .textFieldStyle(.plain)

                // Send button — fixed frame, never resizes
                Button {
                    send()
                } label: {
                    Group {
                        if isSending || isProcessingMedia {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.title2)
                        }
                    }
                    .frame(width: 32, height: 32)
                }
                .disabled(!canSend)
                .tint(Color.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(Color(.systemBackground))
        .fullScreenCover(isPresented: $showCamera) {
            CameraPickerView(
                onPhotoCaptured: { image in
                    showCamera = false
                    processPhoto(image)
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .onChange(of: selectedPhotos) { _, newItems in
            processSelectedPhotos(newItems)
            selectedPhotos = []
        }
        .onChange(of: isSending) { old, new in
            // Clear composer after sending completes (500ms min loading done)
            if old == true && new == false {
                text = ""
                visibility = .shared
                mediaItems = []
                processingCount = 0
                isFocused = false
            }
        }
    }

    // MARK: - Send

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !mediaItems.isEmpty else { return }

        let currentVisibility = visibility
        let currentMedia = mediaItems
        onSend(trimmed, currentVisibility, currentMedia)

        // Don't clear here — wait for isSendingPost to finish (500ms min)
        // Composer clears via onChange(of: isSending) below
    }

    // MARK: - Photo Processing

    private func processPhoto(_ image: UIImage) {
        processingCount += 1
        isProcessingMedia = true

        Task {
            defer {
                processingCount -= 1
                if processingCount == 0 { isProcessingMedia = false }
            }

            do {
                let compressed = try await MediaCompressor.compressPhoto(image)
                let thumbnail = MediaCompressor.generateThumbnail(from: image) ?? image

                let item = MediaItem(
                    type: .photo,
                    thumbnail: thumbnail,
                    sourceData: compressed
                )
                mediaItems.append(item)
            } catch {
                print("[Composer] Photo processing failed: \(error)")
            }
        }
    }

    private func processSelectedPhotos(_ pickerItems: [PhotosPickerItem]) {
        guard !pickerItems.isEmpty else { return }
        processingCount += pickerItems.count
        isProcessingMedia = true

        for pickerItem in pickerItems {
            Task {
                defer {
                    processingCount -= 1
                    if processingCount == 0 { isProcessingMedia = false }
                }

                // Try loading as image
                if let data = try? await pickerItem.loadTransferable(type: Data.self) {
                    if let image = UIImage(data: data) {
                        do {
                            let compressed = try await MediaCompressor.compressPhoto(image)
                            let thumbnail = MediaCompressor.generateThumbnail(from: image) ?? image
                            let item = MediaItem(type: .photo, thumbnail: thumbnail, sourceData: compressed)
                            await MainActor.run { mediaItems.append(item) }
                        } catch {
                            print("[Composer] Photo processing failed: \(error)")
                        }
                    }
                }
            }
        }
    }
}
