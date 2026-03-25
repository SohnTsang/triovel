import SwiftUI

struct DayRibbonView: View {
    let days: [TimelineDay]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        DayChip(
                            dayNumber: day.dayNumber,
                            shortDate: day.shortDate,
                            isSelected: index == selectedIndex
                        )
                        .id(day.dayNumber)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedIndex = index
                            }
                        }
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
            .onChange(of: selectedIndex) { _, newIndex in
                let dayNumber = days.indices.contains(newIndex) ? days[newIndex].dayNumber : 1
                withAnimation {
                    proxy.scrollTo(dayNumber, anchor: .center)
                }
            }
        }
    }
}

private struct DayChip: View {
    let dayNumber: Int
    let shortDate: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("timeline.day \(dayNumber)")
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
            Text(shortDate)
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor : Color(.systemGray6))
        .foregroundStyle(isSelected ? .white : .primary)
        .clipShape(Capsule())
    }
}
