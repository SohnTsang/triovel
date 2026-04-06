import SwiftUI
import UIKit

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
            .background(SwipeBackGestureEnabler())
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

/// Re-enables the interactive pop (swipe-back) gesture that SwiftUI
/// disables when `.navigationBarBackButtonHidden(true)` is set.
private struct SwipeBackGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        SwipeBackController()
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}

    private final class SwipeBackController: UIViewController {
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            // Walk up to the nearest UINavigationController and
            // re-enable its interactivePopGestureRecognizer.
            if let nav = navigationController {
                nav.interactivePopGestureRecognizer?.isEnabled = true
                nav.interactivePopGestureRecognizer?.delegate = nil
            }
        }
    }
}

extension View {
    /// Replaces the system glass back button with a plain chevron.
    func plainBackButton() -> some View {
        modifier(PlainBackButton())
    }
}
