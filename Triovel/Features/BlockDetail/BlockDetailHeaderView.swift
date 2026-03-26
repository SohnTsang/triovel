import SwiftUI

/// Block header showing title, context chip, time, and optional location.
/// Editable by block creator or trip owner only.
struct BlockDetailHeaderView: View {
    let block: Block
    let canEdit: Bool
    @Binding var isEditing: Bool
    @Binding var editTitle: String
    @Binding var editLocation: String
    let onSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditing {
                editingContent
            } else {
                displayContent
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    // MARK: - Display Mode

    @ViewBuilder
    private var displayContent: some View {
        HStack {
            ContextChip(context: block.context)
            Spacer()
            if canEdit {
                Button {
                    editTitle = block.title
                    editLocation = block.locationText ?? ""
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }

        Text(block.title)
            .font(.title2.weight(.semibold))

        HStack(spacing: 12) {
            Label {
                Text(block.startAt, format: .dateTime.hour().minute())
            } icon: {
                Image(systemName: "clock")
            }
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let location = block.locationText, !location.isEmpty {
                Label(location, systemImage: "mappin")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Editing Mode

    @ViewBuilder
    private var editingContent: some View {
        HStack {
            Text("block.edit.title")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
            Spacer()
            Button(String(localized: "common.cancel")) {
                isEditing = false
            }
            .font(.subheadline)
            Button(String(localized: "common.save")) {
                onSave()
            }
            .font(.subheadline.weight(.semibold))
        }

        TextField(String(localized: "block.edit.title.placeholder"), text: $editTitle)
            .font(.title3)
            .padding(8)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))

        TextField(String(localized: "block.edit.location.placeholder"), text: $editLocation)
            .font(.subheadline)
            .padding(8)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 8))
    }
}
