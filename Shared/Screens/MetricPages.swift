import SwiftUI

/// Empty placeholder screens shared by both apps — native ContentUnavailableView.
/// (Sleep & Recovery now have full screens; Strain follows.)

struct StrainView: View {
    var body: some View {
        ContentUnavailableView(
            "No Strain Data",
            systemImage: "flame",
            description: Text("Strain tracking arrives with the ring.")
        )
    }
}
