import SwiftUI

/// Full-screen timezone picker. Navigated to from block edit sheet.
/// Shows "Timezone same as trip" at top, then all UTC offsets.
struct TimezonePickerView: View {
    @Binding var selection: String
    let tripDisplayTimezone: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                button(
                    label: String(localized: "block.edit.timezone.same.as.trip"),
                    subtitle: TimezoneList.displayLabel(for: tripDisplayTimezone),
                    isSelected: selection.isEmpty
                ) {
                    selection = ""
                    dismiss()
                }
            }

            Section {
                ForEach(TimezoneList.all) { tz in
                    button(
                        label: tz.label,
                        subtitle: nil,
                        isSelected: selection == tz.identifier
                    ) {
                        selection = tz.identifier
                        dismiss()
                    }
                }
            }
        }
        .navigationTitle(String(localized: "block.edit.timezone.picker.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func button(label: String, subtitle: String?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
