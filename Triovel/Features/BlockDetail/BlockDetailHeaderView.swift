import SwiftUI

/// Block header showing title, context chip, time, location, and description.
/// Editable by block creator or trip owner only.
/// Edit mode uses a compact grouped layout — not 4 full-width stacked inputs.
struct BlockDetailHeaderView: View {
    let block: Block
    let canEdit: Bool
    @Binding var isEditing: Bool
    @Binding var editTitle: String
    @Binding var editLocation: String
    @Binding var editDescription: String
    @Binding var editTime: Date
    let onSave: () -> Void

    @FocusState private var focusedField: EditField?

    private enum EditField {
        case title, description, location
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
        .animation(.easeInOut(duration: 0.2), value: isEditing)
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
                    editDescription = block.description ?? ""
                    editTime = block.startAt
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
                editTime = block.startAt
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

    // MARK: - Editing Mode (compact grouped layout)

    @ViewBuilder
    private var editingContent: some View {
        // Toolbar: cancel / title / save
        HStack {
            Button {
                focusedField = nil
                isEditing = false
            } label: {
                Text("common.cancel")
                    .font(.subheadline)
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
                Text("common.save")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(
                        editTitle.trimmingCharacters(in: .whitespaces).isEmpty
                            ? Color(.systemGray3) : Color.accentColor
                    )
            }
            .disabled(editTitle.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.bottom, 4)

        // Grouped card with all fields
        VStack(spacing: 0) {
            // Title row
            editRow(icon: "textformat", label: "block.edit.title.label") {
                TextField(String(localized: "block.edit.title.placeholder"), text: $editTitle)
                    .focused($focusedField, equals: .title)
                    .onChange(of: editTitle) { _, v in
                        if v.count > 150 { editTitle = String(v.prefix(150)) }
                    }
            }

            Divider().padding(.leading, 44)

            // Location row
            editRow(icon: "mappin", label: "block.edit.location.label") {
                TextField(String(localized: "block.edit.location.placeholder"), text: $editLocation)
                    .focused($focusedField, equals: .location)
                    .onChange(of: editLocation) { _, v in
                        if v.count > 100 { editLocation = String(v.prefix(100)) }
                    }
            }

            Divider().padding(.leading, 44)

            // Time row
            editRow(icon: "clock", label: "block.edit.time.label") {
                DatePicker("", selection: $editTime, displayedComponents: .hourAndMinute)
                    .labelsHidden()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider().padding(.leading, 44)

            // Description row (taller, multiline)
            editRow(icon: "text.alignleft", label: "block.edit.description.label") {
                TextField(
                    String(localized: "block.detail.description.placeholder"),
                    text: $editDescription,
                    axis: .vertical
                )
                .lineLimit(2...6)
                .focused($focusedField, equals: .description)
                .onChange(of: editDescription) { _, v in
                    if v.count > 500 { editDescription = String(v.prefix(500)) }
                }
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Compact Edit Row

    private func editRow<Content: View>(
        icon: String,
        label: LocalizedStringKey,
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)

                content()
                    .font(.body)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
}
