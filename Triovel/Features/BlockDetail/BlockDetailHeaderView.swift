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
        .padding(20)
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
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ColorTokens.secondaryLabel)
                }
            }
        }

        Text(block.title)
            .font(TypographyTokens.screenTitle)
            .foregroundStyle(ColorTokens.label)

        HStack(spacing: 12) {
            Label {
                Text(block.startAt, format: .dateTime.hour().minute())
            } icon: {
                Image(systemName: "clock")
            }
            .font(TypographyTokens.caption)
            .foregroundStyle(ColorTokens.secondaryLabel)

            if let location = block.locationText, !location.isEmpty {
                Label(location, systemImage: "mappin")
                    .font(TypographyTokens.caption)
                    .foregroundStyle(ColorTokens.secondaryLabel)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Editing Mode

    @ViewBuilder
    private var editingContent: some View {
        HStack {
            Text("block.edit.title")
                .font(TypographyTokens.captionMedium)
                .foregroundStyle(ColorTokens.secondaryLabel)
            Spacer()
            Button(String(localized: "common.cancel")) {
                isEditing = false
            }
            .font(.subheadline)
            .foregroundStyle(ColorTokens.accent)

            Button(String(localized: "common.save")) {
                onSave()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ColorTokens.accent)
        }

        TriovelTextField(
            placeholder: "block.edit.title.placeholder",
            text: $editTitle
        )

        TriovelTextField(
            placeholder: "block.edit.location.placeholder",
            text: $editLocation
        )
    }
}
