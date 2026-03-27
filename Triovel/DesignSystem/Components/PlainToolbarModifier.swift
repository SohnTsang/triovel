import SwiftUI

/// Hides the system back button (which has Liquid Glass on iOS 26)
/// and replaces it with a plain chevron matching the app's clean style.
/// Apply to every view pushed onto a NavigationStack.
struct PlainBackButton: ViewModifier {
    @Environment(\.dismiss) private var dismiss

    func body(content: Content) -> some View {
        content
            .navigationBarBackButtonHidden(true)
            .toolbar {
                if #available(iOS 26, *) {
                    ToolbarItem(placement: .topBarLeading) {
                        backButton
                    }
                    .sharedBackgroundVisibility(.hidden)
                } else {
                    ToolbarItem(placement: .topBarLeading) {
                        backButton
                    }
                }
            }
    }

    private var backButton: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(.label))
        }
    }
}

extension View {
    /// Replaces the system glass back button with a plain chevron.
    func plainBackButton() -> some View {
        modifier(PlainBackButton())
    }
}
