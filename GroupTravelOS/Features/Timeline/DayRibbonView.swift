import SwiftUI

struct DayRibbonView: View {
    let dayCount: Int
    @Binding var selectedDay: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(1...dayCount, id: \.self) { day in
                        DayChip(
                            day: day,
                            isSelected: day == selectedDay
                        )
                        .id(day)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedDay = day
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .onChange(of: selectedDay) { _, newDay in
                withAnimation {
                    proxy.scrollTo(newDay, anchor: .center)
                }
            }
        }
    }
}

private struct DayChip: View {
    let day: Int
    let isSelected: Bool

    var body: some View {
        Text("Day \(day)")
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor : Color(.systemGray6))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
    }
}
