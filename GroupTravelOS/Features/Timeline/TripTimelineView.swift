import SwiftUI

struct TripTimelineView: View {
    let tripId: String
    @EnvironmentObject private var router: Router

    @State private var selectedDay: Int = 1
    @State private var activeFilter: TimelineFilter = .all
    @State private var showingAddMoment = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Sticky day ribbon
                DayRibbonView(
                    dayCount: 5, // Placeholder — will come from trip
                    selectedDay: $selectedDay
                )

                // Filter bar
                FilterBarView(activeFilter: $activeFilter)

                // Day content
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Placeholder — will be populated with blocks + ghost blocks
                        Text("Day \(selectedDay)")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }

            // Floating + Add Moment button
            Button {
                showingAddMoment = true
            } label: {
                Label("Add Moment", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color.accentColor, in: Capsule())
                    .shadow(radius: 4, y: 2)
            }
            .padding(24)
        }
        .navigationTitle("Trip") // Will use actual trip title
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    router.push(.tripSummary(tripId: tripId))
                } label: {
                    Image(systemName: "chart.bar")
                }
            }
        }
        .sheet(isPresented: $showingAddMoment) {
            AddMomentView(tripId: tripId, defaultDay: selectedDay)
        }
    }
}
