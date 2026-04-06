import SwiftUI
import PhotosUI
import Supabase

/// Sheet for editing trip settings. Only trip owner can access.
/// Pre-filled with current values. Same layout as TripSetupView.
struct EditTripView: View {
    let trip: Trip
    let onSaved: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var displayTimezone: String
    @State private var baseCurrency: String
    @State private var isSaving = false
    @State private var errorMessage: String?
    @FocusState private var titleFocused: Bool

    // Cover image
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var coverPreview: UIImage?
    @State private var isProcessingCover = false
    @State private var coverChanged = false

    private let tripRepository = TripRepository()
    private let storageBucket = "trip-media"

    init(trip: Trip, onSaved: @escaping () -> Void) {
        self.trip = trip
        self.onSaved = onSaved
        _title = State(initialValue: trip.title)
        _startDate = State(initialValue: trip.startDate)
        _endDate = State(initialValue: trip.endDate)
        _displayTimezone = State(initialValue: trip.displayTimezone)
        _baseCurrency = State(initialValue: trip.baseCurrency)
    }

    private var hasChanges: Bool {
        title.trimmingCharacters(in: .whitespaces) != trip.title
        || !Calendar.current.isDate(startDate, inSameDayAs: trip.startDate)
        || !Calendar.current.isDate(endDate, inSameDayAs: trip.endDate)
        || displayTimezone != trip.displayTimezone
        || baseCurrency != trip.baseCurrency
        || coverChanged
    }

    var body: some View {
        NavigationStack {
            Form {
                // Cover image section
                Section {
                    coverImageSection
                }

                Section {
                    TextField(String(localized: "trip.setup.name.placeholder"), text: $title)
                        .font(.title3)
                        .focused($titleFocused)
                        .onChange(of: title) { _, newValue in
                            if newValue.count > 100 { title = String(newValue.prefix(100)) }
                        }
                }

                Section {
                    DatePicker(
                        String(localized: "trip.setup.start.date"),
                        selection: $startDate,
                        displayedComponents: .date
                    )
                    DatePicker(
                        String(localized: "trip.setup.end.date"),
                        selection: $endDate,
                        in: startDate...,
                        displayedComponents: .date
                    )
                }

                Section {
                    Picker(String(localized: "trip.edit.currency"), selection: $baseCurrency) {
                        ForEach(commonCurrencies, id: \.self) { code in
                            Text(code).tag(code)
                        }
                    }
                }

                Section {
                    Picker(String(localized: "trip.edit.timezone"), selection: $displayTimezone) {
                        ForEach(TimezoneList.all) { tz in
                            Text(tz.label).tag(tz.identifier)
                        }
                    }
                } footer: {
                    Text("trip.edit.timezone.helper")
                        .font(.caption)
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(String(localized: "trip.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button(String(localized: "common.save")) { saveTrip() }
                            .disabled(
                                title.trimmingCharacters(in: .whitespaces).isEmpty
                                || !hasChanges
                                || isProcessingCover
                            )
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onChange(of: startDate) { _, newStart in
                if endDate < newStart {
                    endDate = Calendar.current.date(byAdding: .day, value: 1, to: newStart) ?? newStart
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                processSelectedPhoto(newItem)
            }
        }
    }

    // MARK: - Cover Image Section

    @ViewBuilder
    private var coverImageSection: some View {
        VStack(spacing: 12) {
            // Preview
            ZStack {
                if let preview = coverPreview {
                    Image(uiImage: preview)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                } else if let path = trip.coverImagePath, !path.isEmpty {
                    CachedMediaView(
                        mediaId: "trip-cover-\(trip.id)",
                        storagePath: path,
                        mediaType: .photo
                    )
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.systemGray5))
                        .frame(height: 220)
                        .overlay {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundStyle(.quaternary)
                        }
                }

                // Processing overlay
                if isProcessingCover {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.black.opacity(0.3))
                        .frame(height: 220)
                        .overlay {
                            ProgressView()
                                .tint(.white)
                        }
                }
            }

            let hasCover = trip.coverImagePath != nil || coverPreview != nil
            PhotosPicker(
                selection: $selectedPhoto,
                matching: .images
            ) {
                Text(hasCover
                     ? "trip.edit.cover.change"
                     : "trip.edit.cover.add")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
        }
    }

    // MARK: - Photo Processing

    private func processSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isProcessingCover = true

        Task {
            defer { isProcessingCover = false }

            guard let data = try? await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = String(localized: "trip.edit.cover.error")
                return
            }

            // Compress to 1.5MB target
            do {
                _ = try await MediaCompressor.compressPhoto(image)
                let thumbnail = MediaCompressor.generateThumbnail(from: image) ?? image
                coverPreview = thumbnail
                coverChanged = true
            } catch {
                errorMessage = String(localized: "trip.edit.cover.error")
            }
        }
    }

    // MARK: - Save

    private func saveTrip() {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isSaving = true
        errorMessage = nil

        Task {
            let start = ContinuousClock.now
            do {
                var newCoverPath: String? = nil

                // Upload cover image if changed
                if coverChanged, let preview = coverPreview,
                   let jpegData = preview.jpegData(compressionQuality: 0.8) {
                    // Compress properly
                    let compressed = try await MediaCompressor.compressPhoto(
                        UIImage(data: jpegData) ?? preview
                    )
                    let remotePath = "covers/\(trip.id).jpg"

                    // Upload (upsert to overwrite existing)
                    _ = try await SupabaseConfig.client.storage
                        .from(storageBucket)
                        .upload(
                            remotePath,
                            data: compressed,
                            options: FileOptions(contentType: "image/jpeg", upsert: true)
                        )
                    newCoverPath = remotePath
                    print("[EditTrip] Cover uploaded: \(remotePath)")
                }

                try await tripRepository.updateTrip(
                    tripId: trip.id,
                    title: trimmed != trip.title ? trimmed : nil,
                    startDate: !Calendar.current.isDate(startDate, inSameDayAs: trip.startDate) ? startDate : nil,
                    endDate: !Calendar.current.isDate(endDate, inSameDayAs: trip.endDate) ? endDate : nil,
                    displayTimezone: displayTimezone != trip.displayTimezone ? displayTimezone : nil,
                    baseCurrency: baseCurrency != trip.baseCurrency ? baseCurrency : nil,
                    coverImagePath: newCoverPath
                )

                let elapsed = ContinuousClock.now - start
                if elapsed < .milliseconds(500) {
                    try? await Task.sleep(for: .milliseconds(500) - elapsed)
                }

                dismiss()
                onSaved()
            } catch {
                print("[EditTrip] ❌ Save failed: \(error)")
                errorMessage = String(localized: "trip.edit.error")
                isSaving = false
            }
        }
    }

    // MARK: - Helpers

    private let commonCurrencies = [
        "USD", "EUR", "GBP", "JPY", "AUD", "CAD", "CHF",
        "CNY", "HKD", "NZD", "SGD", "KRW", "TWD", "THB",
        "MYR", "PHP", "IDR", "VND", "INR", "BRL", "MXN",
    ]
}
