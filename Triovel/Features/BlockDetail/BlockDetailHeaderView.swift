import SwiftUI

/// Block header showing title, context chip, time, location, and description.
/// Editable by block creator or trip owner only.
/// Edit mode uses a compact grouped layout: Title → Location + Time row → Details.
struct BlockDetailHeaderView: View {
    let block: Block
    let canEdit: Bool
    var isSaving: Bool = false
    @Binding var isEditing: Bool
    @Binding var editTitle: String
    @Binding var editLocation: String
    @Binding var editDescription: String
    @Binding var editStartAt: Date
    let onSave: () -> Void

    @FocusState private var focusedField: EditField?

    private enum EditField {
        case title, location, description
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
        // Context chip + edit button
        HStack {
            ContextChip(context: block.context)
            Spacer()
            if canEdit {
                Button {
                    editTitle = block.title
                    editLocation = block.locationText ?? ""
                    editDescription = block.description ?? ""
                    editStartAt = block.startAt
                    isEditing = true
                } label: {
                    Image(systemName: "pencil")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color(.label))
                }
            }
        }

        // Time
        Label {
            Text(block.startAt, format: .dateTime.hour().minute())
        } icon: {
            Image(systemName: "clock")
        }
        .font(.subheadline)
        .foregroundStyle(.secondary)

        // Title
        Text(block.title)
            .font(.title2.weight(.semibold))
            .lineLimit(3)

        // Location
        if let location = block.locationText, !location.isEmpty {
            Label(location, systemImage: "mappin")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }

        // Description
        if let description = block.description, !description.isEmpty {
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(5)
        } else if canEdit {
            Button {
                editTitle = block.title
                editLocation = block.locationText ?? ""
                editDescription = ""
                editStartAt = block.startAt
                isEditing = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    focusedField = .description
                }
            } label: {
                Text("block.detail.description.placeholder")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Editing Mode (Compact Grouped Layout)

    @ViewBuilder
    private var editingContent: some View {
        // Action bar: Cancel — "Edit" — Save
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

            Spacer()

            Button {
                focusedField = nil
                onSave()
            } label: {
                Group {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(
                                editTitle.trimmingCharacters(in: .whitespaces).isEmpty
                                    ? Color(.systemGray3) : Color.accentColor
                            )
                    }
                }
                .frame(width: 28, height: 28)
            }
            .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
        }
        .padding(.bottom, 4)

        // Compact grouped card
        VStack(spacing: 0) {
            // Row 1: Title
            editRow {
                HStack(spacing: 10) {
                    Image(systemName: "textformat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    TextField(String(localized: "block.edit.title.placeholder"), text: $editTitle)
                        .font(.body)
                        .focused($focusedField, equals: .title)
                        .onChange(of: editTitle) { _, newValue in
                            if newValue.count > 150 { editTitle = String(newValue.prefix(150)) }
                        }
                }
            }

            groupDivider

            // Row 2: Location
            editRow {
                HStack(spacing: 10) {
                    Image(systemName: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    TextField(String(localized: "block.edit.location.placeholder"), text: $editLocation)
                        .font(.body)
                        .focused($focusedField, equals: .location)
                        .onChange(of: editLocation) { _, newValue in
                            if newValue.count > 100 { editLocation = String(newValue.prefix(100)) }
                        }
                }
            }

            groupDivider

            // Row 3: Time
            editRow {
                HStack(spacing: 10) {
                    Image(systemName: "clock")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                    DatePicker(
                        "",
                        selection: $editStartAt,
                        displayedComponents: .hourAndMinute
                    )
                    .labelsHidden()
                    Spacer()
                }
            }

            groupDivider

            // Row 4: Details (taller)
            editRow(minHeight: 80) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "text.alignleft")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                        .padding(.top, 2)
                    TextField(
                        String(localized: "block.detail.description.placeholder"),
                        text: $editDescription,
                        axis: .vertical
                    )
                    .font(.body)
                    .lineLimit(3...8)
                    .focused($focusedField, equals: .description)
                    .onChange(of: editDescription) { _, newValue in
                        if newValue.count > 500 { editDescription = String(newValue.prefix(500)) }
                    }
                }
            }
        }
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    /// A single row inside the grouped edit card.
    private func editRow<Content: View>(minHeight: CGFloat = 44, @ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, 14)
            .frame(minHeight: minHeight, alignment: .center)
    }

    /// Thin divider inside the grouped card.
    private var groupDivider: some View {
        Divider()
            .padding(.leading, 44)
    }
}
