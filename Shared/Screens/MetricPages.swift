import SwiftUI

/// Empty placeholder screens shared by both apps — native ContentUnavailableView.

struct SleepView: View {
    var body: some View {
        ContentUnavailableView(
            "No Sleep Data",
            systemImage: "bed.double",
            description: Text("Sleep tracking arrives when your Colmi R09 does.")
        )
    }
}

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
