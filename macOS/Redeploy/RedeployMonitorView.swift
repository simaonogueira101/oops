import SwiftUI

struct RedeployMonitorView: View {
    @Bindable var service: RedeployService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            expiryHeader

            Toggle(isOn: Binding(
                get: { service.isEnabled },
                set: { on in Task { on ? await service.enable() : await service.disable() } }
            )) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Auto-redeploy").font(.subheadline.weight(.medium))
                    Text("Re-signs Oops every \(service.intervalDays) days while your iPhone is reachable")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            Divider()

            row("Last redeploy", lastRunText, color: lastRunColor)
            row("Schedule", service.isEnabled ? "every \(service.intervalDays) days" : "off")

            Button {
                Task { await service.redeployNow() }
            } label: {
                if service.isRedeploying {
                    HStack(spacing: 6) { ProgressView().controlSize(.small); Text("Redeploying…") }
                        .frame(maxWidth: .infinity)
                } else {
                    Label("Redeploy now", systemImage: "arrow.triangle.2.circlepath")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(service.isRedeploying)

            Text("Needs your iPhone on the same Wi-Fi (or plugged in) when it runs.")
                .font(.caption2).foregroundStyle(.tertiary)
        }
        .padding(14)
        .task { await service.refresh() }
    }

    private var expiryHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: expiryIcon)
                .font(.system(size: 28))
                .foregroundStyle(expiryColor)
                .symbolRenderingMode(.hierarchical)
            VStack(alignment: .leading, spacing: 1) {
                Text(expiryTitle).font(.headline)
                Text("Free signing lasts 7 days; each redeploy resets it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func row(_ label: String, _ value: String, color: Color = .primary) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).foregroundStyle(color)
        }
        .font(.subheadline)
    }

    // MARK: Derived

    private var expiryTitle: String {
        guard let d = service.daysUntilExpiry else { return "Not deployed yet" }
        if d < 0 { return "Expired — redeploy needed" }
        if d == 0 { return "Expires today" }
        return "Valid for \(d) more day\(d == 1 ? "" : "s")"
    }
    private var expiryColor: Color {
        guard let d = service.daysUntilExpiry else { return .secondary }
        if d < 0 { return .red }
        if d <= 2 { return .orange }
        return .green
    }
    private var expiryIcon: String {
        guard let d = service.daysUntilExpiry, d >= 0 else { return "exclamationmark.triangle.fill" }
        return "checkmark.seal.fill"
    }

    private var lastRunText: String {
        guard let s = service.status else { return "never" }
        let when = s.date.formatted(.relative(presentation: .named))
        return "\(s.success ? "✓" : "✗") \(s.message) · \(when)"
    }
    private var lastRunColor: Color {
        guard let s = service.status else { return .secondary }
        return s.success ? .green : .red
    }
}
