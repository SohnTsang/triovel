import SwiftUI
import UIKit

/// A UIKit-backed menu button that presents a dropdown without
/// animating/moving the trigger icon. SwiftUI's `Menu` on iOS 26
/// has a bug where the label bounces on dismiss.
struct UIKitMenuButton: UIViewRepresentable {
    let icon: String
    let actions: [MenuAction]

    struct MenuAction: Identifiable {
        let id = UUID()
        let title: String
        let image: String?
        let isDestructive: Bool
        let handler: () -> Void

        init(_ title: String, image: String? = nil, isDestructive: Bool = false, handler: @escaping () -> Void) {
            self.title = title
            self.image = image
            self.isDestructive = isDestructive
            self.handler = handler
        }
    }

    struct Separator: Identifiable {
        let id = UUID()
    }

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setImage(UIImage(systemName: icon, withConfiguration: UIImage.SymbolConfiguration(weight: .semibold)), for: .normal)
        button.tintColor = .label
        button.showsMenuAsPrimaryAction = true
        button.menu = buildMenu()
        return button
    }

    func updateUIView(_ button: UIButton, context: Context) {
        button.menu = buildMenu()
    }

    private func buildMenu() -> UIMenu {
        // Group actions by destructive separator
        var normalActions: [UIAction] = []
        var destructiveActions: [UIAction] = []

        for action in actions {
            let uiAction = UIAction(
                title: action.title,
                image: action.image.flatMap { UIImage(systemName: $0) },
                attributes: action.isDestructive ? .destructive : []
            ) { _ in
                action.handler()
            }

            if action.isDestructive {
                destructiveActions.append(uiAction)
            } else {
                normalActions.append(uiAction)
            }
        }

        if destructiveActions.isEmpty {
            return UIMenu(children: normalActions)
        }

        let normalGroup = UIMenu(options: .displayInline, children: normalActions)
        let destructiveGroup = UIMenu(options: .displayInline, children: destructiveActions)
        return UIMenu(children: [normalGroup, destructiveGroup])
    }
}
