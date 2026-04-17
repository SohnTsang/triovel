import SwiftUI
import QuickLook

/// All documents across a trip, grouped by Day → Block title.
struct TripFilesView: View {
    let tripId: String

    @Environment(AppState.self) private var appState
    @State private var sections: [FileDaySection] = []
    @State private var isLoading = false
    @State private var previewURL: URL?

    private let docRepo = BlockDocumentRepository()
    private let blockRepo = BlockRepository()

    var body: some View {
        Group {
            if isLoading {
                VStack { Spacer(); ProgressView().controlSize(.regular); Spacer() }
            } else if sections.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "doc.text")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("trip.files.empty")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        ForEach(sections) { daySection in
                            // Day header
                            Text(daySection.title)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                                .padding(.horizontal, 16)

                            ForEach(daySection.blocks) { blockSection in
                                // Block title
                                Text(blockSection.blockTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 16)

                                // Documents list
                                VStack(alignment: .leading, spacing: 0) {
                                    ForEach(blockSection.documents) { doc in
                                        fileRow(doc)
                                        if doc.id != blockSection.documents.last?.id {
                                            Divider().padding(.leading, 40)
                                        }
                                    }
                                }
                                .background {
                                    RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground))
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 0.5)
                                )
                                .shadow(color: .black.opacity(0.06), radius: 2, x: 0, y: 2)
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .navigationTitle(String(localized: "trip.files.title"))
        .navigationBarTitleDisplayMode(.inline)
        .plainBackButton()
        .quickLookPreview($previewURL)
        .task {
            await loadFiles()
        }
    }

    // MARK: - File Row

    private func fileRow(_ doc: BlockDocument) -> some View {
        HStack(spacing: 10) {
            Image(systemName: doc.fileType == .pdf ? "doc.fill" : "photo.fill")
                .font(.subheadline)
                .foregroundStyle(doc.fileType == .pdf ? Color.red : Color.blue)
                .frame(width: 24)

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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
        .onTapGesture {
            openPreview(doc)
        }
    }

    // MARK: - Preview

    private func openPreview(_ doc: BlockDocument) {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let localFile = docsDir.appendingPathComponent("Documents/\(doc.id)/\(doc.fileName)")
        if FileManager.default.fileExists(atPath: localFile.path) {
            previewURL = localFile
            return
        }

        guard let storagePath = doc.storagePath else { return }
        Task {
            do {
                let url = try await DocumentFileManager.shared.download(
                    docId: doc.id, fileName: doc.fileName, storagePath: storagePath
                )
                previewURL = url
            } catch {
                print("[TripFiles] ❌ Preview download failed: \(error)")
            }
        }
    }

    // MARK: - Load

    private func loadFiles() async {
        isLoading = true
        let start = ContinuousClock.now
        do {
            let trip = try await blockRepo.fetchTrip(tripId: tripId)
            let blocks = try await blockRepo.fetchBlocks(tripId: tripId)

            let tz = TimeZone(identifier: trip.displayTimezone) ?? .current
            var cal = Calendar.current
            cal.timeZone = tz
            let tripStart = cal.startOfDay(for: trip.startDate)

            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "MMM d"
            dateFormatter.timeZone = tz

            // Fetch docs for each block
            var dayMap: [Int: [FileBlockSection]] = [:]

            for block in blocks {
                let docs = try await docRepo.fetchDocuments(blockId: block.id)
                guard !docs.isEmpty else { continue }

                let blockDay = cal.startOfDay(for: block.startAt)
                let dayNumber = max(1, cal.dateComponents([.day], from: tripStart, to: blockDay).day! + 1)

                let blockSection = FileBlockSection(
                    blockId: block.id,
                    blockTitle: block.title,
                    documents: docs
                )
                dayMap[dayNumber, default: []].append(blockSection)
            }

            sections = dayMap.sorted { $0.key < $1.key }.map { dayNum, blockSections in
                let dayDate = cal.date(byAdding: .day, value: dayNum - 1, to: tripStart) ?? tripStart
                let dateStr = dateFormatter.string(from: dayDate)
                return FileDaySection(
                    dayNumber: dayNum,
                    title: String(localized: "timeline.day \(dayNum)") + " · " + dateStr,
                    blocks: blockSections
                )
            }
        } catch {
            print("[TripFiles] ❌ Failed to load files: \(error)")
        }
        let elapsed = ContinuousClock.now - start
        if elapsed < .milliseconds(500) {
            try? await Task.sleep(for: .milliseconds(500) - elapsed)
        }
        isLoading = false
    }
}

// MARK: - Models

private struct FileDaySection: Identifiable {
    let dayNumber: Int
    let title: String
    let blocks: [FileBlockSection]
    var id: Int { dayNumber }
}

private struct FileBlockSection: Identifiable {
    let blockId: String
    let blockTitle: String
    let documents: [BlockDocument]
    var id: String { blockId }
}
