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

    @FocusState private var focusedField: EditField?

    private enum EditField {
        case title, location
    }

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
        .contentShape(Rectangle())
        .onTapGesture {
            focusedField = nil
        }
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
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(.label))
                }
            }
        }

        Text(block.title)
            .font(.title2.weight(.semibold))
            .lineLimit(3)

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
        // Header with X and checkmark icons
        HStack {
            Button {
                focusedField = nil
                isEditing = false
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("block.edit.title")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)

            Spacer()

            Button {
                focusedField = nil
                onSave()
            } label: {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(editTitle.trimmingCharacters(in: .whitespaces).isEmpty ? Color(.systemGray3) : Color.accentColor)
            }
            .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }

        // Title field
        VStack(alignment: .leading, spacing: 4) {
            Text("block.edit.title.label")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(String(localized: "block.edit.title.placeholder"), text: $editTitle)
                .font(.body)
                .focused($focusedField, equals: .title)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(focusedField == .title ? Color.accentColor : Color(.systemGray4), lineWidth: focusedField == .title ? 1.5 : 1)
                )
                .onChange(of: editTitle) { _, newValue in
                    if newValue.count > 150 { editTitle = String(newValue.prefix(150)) }
                }
        }

        // Location field
        VStack(alignment: .leading, spacing: 4) {
            Text("block.edit.location.label")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextField(String(localized: "block.edit.location.placeholder"), text: $editLocation)
                .font(.body)
                .focused($focusedField, equals: .location)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(focusedField == .location ? Color.accentColor : Color(.systemGray4), lineWidth: focusedField == .location ? 1.5 : 1)
                )
                .onChange(of: editLocation) { _, newValue in
                    if newValue.count > 100 { editLocation = String(newValue.prefix(100)) }
                }
        }
    }
}
