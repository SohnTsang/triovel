import SwiftUI

struct DayRibbonView: View {
    let days: [TimelineDay]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                        DayPill(
                            dayNumber: day.dayNumber,
                            shortDate: day.shortDate,
                            isSelected: index == selectedIndex
                        )
                        .id(day.dayNumber)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                selectedIndex = index
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 10)
            .background(ColorTokens.background)
            .onChange(of: selectedIndex) { _, newIndex in
                let dayNumber = days.indices.contains(newIndex) ? days[newIndex].dayNumber : 1
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    proxy.scrollTo(dayNumber, anchor: .center)
                }
            }
        }
    }
}

private struct DayPill: View {
    let dayNumber: Int
    let shortDate: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("timeline.day \(dayNumber)")
                .font(.subheadline.weight(isSelected ? .bold : .medium))
            Text(shortDate)
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : ColorTokens.secondaryLabel)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? ColorTokens.accent : Color(.tertiarySystemBackground))
        .foregroundStyle(isSelected ? .white : ColorTokens.label)
        .clipShape(Capsule())
    }
}
