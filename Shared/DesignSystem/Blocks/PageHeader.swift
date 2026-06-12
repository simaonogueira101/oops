import SwiftUI

/// A scrolling page title shown at the top of every screen. The selected day lives in the
/// top bar's date control, so it isn't repeated here.
struct PageHeader: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.largeTitle.weight(.bold))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

#Preview {
    PageHeader(title: "Summary").padding()
}
