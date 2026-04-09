import SwiftUI

/// A row that can be swiped left to reveal a delete button.
/// Shows a subtle chevron hint on the trailing edge to indicate swipeability.
struct SwipeToDeleteRow<Content: View>: View {
    @ViewBuilder let content: () -> Content
    let onDelete: () -> Void

    @State private var offset: CGFloat = 0
    @State private var showDelete = false

    private let deleteWidth: CGFloat = 80
    private let threshold: CGFloat = 60

    var body: some View {
        ZStack(alignment: .trailing) {
            // Delete background
            if showDelete || offset < -10 {
                HStack {
                    Spacer()
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            offset = 0
                            showDelete = false
                        }
                        onDelete()
                    } label: {
                        Image(systemName: "trash.fill")
                            .font(.body)
                            .foregroundStyle(.white)
                            .frame(width: deleteWidth, height: .infinity)
                    }
                }
                .frame(maxHeight: .infinity)
                .background(Color.red)
            }

            // Content with swipe hint
            HStack(spacing: 0) {
                content()

                // Subtle swipe hint chevron
                if !showDelete && offset == 0 {
                    Image(systemName: "chevron.compact.left")
                        .font(.caption2)
                        .foregroundStyle(Color(.systemGray3))
                        .padding(.trailing, 4)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(.systemBackground))
            .offset(x: offset)
            .gesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        let translation = value.translation.width
                        // Only allow left swipe
                        if translation < 0 {
                            offset = max(translation, -deleteWidth)
                        } else if showDelete {
                            offset = min(0, -deleteWidth + translation)
                        }
                    }
                    .onEnded { value in
                        withAnimation(.easeOut(duration: 0.2)) {
                            if offset < -threshold {
                                offset = -deleteWidth
                                showDelete = true
                            } else {
                                offset = 0
                                showDelete = false
                            }
                        }
                    }
            )
        }
        .clipped()
    }
}
