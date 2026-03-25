import SwiftUI

/// Rounded text field matching visual-design.md specs.
/// 12pt corner radius, tertiarySystemBackground, 12pt horizontal / 14pt vertical padding.
struct TriovelTextField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    var isSecure: Bool = false
    var textContentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .sentences

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
                    .textContentType(textContentType)
            } else {
                TextField(placeholder, text: $text)
                    .textContentType(textContentType)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .background(Color(.tertiarySystemBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
