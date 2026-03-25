import Foundation

/// ViewModel for BlockDetailView. Fetches block from Supabase,
/// determines edit permissions, and handles header edits.
@MainActor
final class BlockDetailViewModel: ObservableObject {
    @Published private(set) var block: Block?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    // Edit state
    @Published var isEditingHeader = false
    @Published var editTitle = ""
    @Published var editLocation = ""

    private var currentUserId: String?
    private var tripOwnerId: String?
    private let blockRepository = BlockRepository()

    /// Only block creator or trip owner can edit header.
    var canEditHeader: Bool {
        guard let userId = currentUserId, let block else { return false }
        return block.createdBy == userId || tripOwnerId == userId
    }

    // MARK: - Load

    func load(blockId: String, userId: String) async {
        currentUserId = userId
        isLoading = true
        errorMessage = nil

        do {
            let fetchedBlock = try await blockRepository.fetchBlock(blockId: blockId)
            self.block = fetchedBlock

            // Fetch trip to determine owner
            let trip = try await blockRepository.fetchTrip(tripId: fetchedBlock.tripId)
            self.tripOwnerId = trip.createdBy
        } catch {
            errorMessage = "Could not load block."
        }

        isLoading = false
    }

    /// Load directly from a block we already have (e.g. after creation).
    func loadDirect(block: Block, userId: String, tripOwnerId: String?) {
        self.block = block
        self.currentUserId = userId
        self.tripOwnerId = tripOwnerId
        self.isLoading = false
    }

    // MARK: - Save Header Edits

    func saveHeaderEdits() {
        guard let block else { return }
        let trimmedTitle = editTitle.trimmingCharacters(in: .whitespaces)
        guard !trimmedTitle.isEmpty else { return }

        let newLocation = editLocation.trimmingCharacters(in: .whitespaces)

        Task {
            do {
                try await blockRepository.updateBlockHeader(
                    blockId: block.id,
                    title: trimmedTitle != block.title ? trimmedTitle : nil,
                    locationText: newLocation != (block.locationText ?? "") ? newLocation : nil,
                    startAt: nil
                )

                // Update local state optimistically
                self.block?.title = trimmedTitle
                self.block?.locationText = newLocation.isEmpty ? nil : newLocation
                isEditingHeader = false
            } catch {
                errorMessage = "Could not save changes."
            }
        }
    }
}
