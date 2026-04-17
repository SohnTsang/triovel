import SwiftUI
import QuickLook
import UniformTypeIdentifiers

/// Compact document list shown in block detail. Each document is one row.
/// Tap to preview (QuickLook). Long-press to delete (own documents only).
struct DocumentSectionView: View {
    let documents: [BlockDocument]
    let currentUserId: String?
    let tripId: String
    var onDelete: ((BlockDocument) -> Void)?
    var onRetry: ((BlockDocument) -> Void)?
    var onRename: ((BlockDocument, String) -> Void)?

    @State private var previewURL: URL?
    @State private var isLoadingPreview = false
    @State private var loadingDocId: String?
    @State private var deleteTarget: BlockDocument?
    @State private var renameTarget: BlockDocument?
    @State private var renameText = ""

    var body: some View {
        if !documents.isEmpty {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(documents) { doc in
                    documentRow(doc)
                    if doc.id != documents.last?.id {
                        Divider()
                            .padding(.leading, 40)
                    }
                }
            }
            .background { RoundedRectangle(cornerRadius: 12).fill(ColorTokens.cardBackground) }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 2)
            .padding(.top, 4)
            .alert(String(localized: "document.delete.title"), isPresented: .init(
                get: { deleteTarget != nil },
                set: { if !$0 { deleteTarget = nil } }
            )) {
                Button(String(localized: "common.cancel"), role: .cancel) { deleteTarget = nil }
                Button(String(localized: "common.delete"), role: .destructive) {
                    if let doc = deleteTarget {
                        onDelete?(doc)
                        deleteTarget = nil
                    }
                }
            } message: {
                Text("document.delete.message")
            }
            .alert(String(localized: "document.rename"), isPresented: .init(
                get: { renameTarget != nil },
                set: { if !$0 { renameTarget = nil } }
            )) {
                TextField(String(localized: "document.rename.placeholder"), text: $renameText)
                Button(String(localized: "common.cancel"), role: .cancel) { renameTarget = nil }
                Button(String(localized: "common.save")) {
                    if let doc = renameTarget {
                        let trimmed = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty {
                            let ext = (doc.fileName as NSString).pathExtension
                            let newName = ext.isEmpty ? trimmed : "\(trimmed).\(ext)"
                            onRename?(doc, newName)
                        }
                        renameTarget = nil
                    }
                }
            } message: {
                Text("document.rename.message")
            }
            .quickLookPreview($previewURL)
        }
    }

    // MARK: - Row

    @ViewBuilder
    private func documentRow(_ doc: BlockDocument) -> some View {
        HStack(spacing: 10) {
            // File type icon
            Image(systemName: doc.fileType == .pdf ? "doc.fill" : "photo.fill")
                .font(.subheadline)
                .foregroundStyle(doc.fileType == .pdf ? Color.red : Color.blue)
                .frame(width: 24)

            // File name + size
            VStack(alignment: .leading, spacing: 1) {
                Text(doc.fileName)
                    .font(.subheadline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                if let size = doc.formattedSize {
                    Text(size)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Upload state
            switch doc.uploadStatus {
            case .queued, .uploading:
                ProgressView()
                    .controlSize(.small)
            case .failed:
                Button {
                    onRetry?(doc)
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.caption)
                        .foregroundStyle(Color.red)
                }
                .buttonStyle(.plain)
            case .uploaded:
                EmptyView()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            if doc.uploadStatus == .failed {
                onRetry?(doc)
            } else {
                openPreview(doc)
            }
        }
        .contextMenu {
            if doc.userId == currentUserId {
                Button {
                    let name = doc.fileName as NSString
                    renameText = name.deletingPathExtension
                    renameTarget = doc
                } label: {
                    Label(String(localized: "document.rename"), systemImage: "pencil")
                }
                Button(role: .destructive) {
                    deleteTarget = doc
                } label: {
                    Label(String(localized: "common.delete"), systemImage: "trash")
                }
            }
        }
    }

    // MARK: - Preview

    private func openPreview(_ doc: BlockDocument) {
        guard !isLoadingPreview else { return }

        // Try local file first
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localFile = docsDir.appendingPathComponent("Documents/\(doc.id)/\(doc.fileName)")
        if FileManager.default.fileExists(atPath: localFile.path) {
            previewURL = localFile
            return
        }

        // Download from remote
        guard let storagePath = doc.storagePath else { return }
        isLoadingPreview = true
        loadingDocId = doc.id

        Task {
            do {
                let url = try await DocumentFileManager.shared.download(
                    docId: doc.id,
                    fileName: doc.fileName,
                    storagePath: storagePath
                )
                previewURL = url
            } catch {
                print("[DocSection] ❌ Preview download failed: \(error)")
            }
            isLoadingPreview = false
            loadingDocId = nil
        }
    }
}

// MARK: - Document Picker (UIKit wrapper)

struct DocumentPickerView: UIViewControllerRepresentable {
    let onPick: (URL, String, DocumentFileType) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let types: [UTType] = [.pdf, .jpeg, .png, .heic]
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: types, asCopy: false)
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL, String, DocumentFileType) -> Void

        init(onPick: @escaping (URL, String, DocumentFileType) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            let fileName = url.lastPathComponent
            let ext = url.pathExtension.lowercased()
            let fileType: DocumentFileType = ext == "pdf" ? .pdf : .image
            onPick(url, fileName, fileType)
        }
    }
}
