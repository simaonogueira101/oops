import SwiftUI

/// Empty placeholder screens shared by both apps — native ContentUnavailableView.
/// (Sleep now has a full screen in `Sleep/SleepView.swift`; Recovery/Strain follow.)

struct RecoveryView: View {
    var body: some View {
        ContentUnavailableView(
            "No Recovery Data",
            systemImage: "heart",
            description: Text("Recovery & HRV arrive with the ring.")
        )
    }
}

struct StrainView: View {
    var body: some View {
        ContentUnavailableView(
            "No Strain Data",
            systemImage: "flame",
            description: Text("Strain tracking arrives with the ring.")
        )
    }
}
