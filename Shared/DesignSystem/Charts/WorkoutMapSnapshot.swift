import SwiftUI
import MapKit

/// A small, non-interactive map placeholder for a workout route. Real GPS arrives with the ring.
struct WorkoutMapSnapshot: View {
    var body: some View {
        Map(initialPosition: .region(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 38.72, longitude: -9.14),
            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02))))
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .allowsHitTesting(false)
    }
}

#Preview {
    WorkoutMapSnapshot().padding()
}
