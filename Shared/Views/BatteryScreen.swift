import SwiftUI

/// The stock-styled battery screen. Reads the ring's battery on demand and shows the
/// latest value, charging state, and when it was last read.
struct BatteryScreen: View {
    let manager: RingManager

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.lg) {
                Spacer()

                Image(systemName: batterySymbol)
                    .font(.heroGlyph)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(accentColor)
                    .contentTransition(.symbolEffect(.replace))

                if let status = manager.batteryStatus {
                    Text("\(status.level)%")
                        .font(.metricValue)
                        .contentTransition(.numericText())

                    Text(status.isCharging ? "Charging" : "Not charging")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No reading yet")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                if let lastUpdated = manager.lastUpdated {
                    Text("Updated \(lastUpdated, format: .relative(presentation: .named))")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }

                if let error = manager.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                        .padding(.top, Spacing.xxs)
                }

                Spacer()

                Button {
                    Task { await manager.refreshBattery() }
                } label: {
                    if manager.isBusy {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Read Battery")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(manager.isBusy)
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Oops")
            .task {
                if manager.batteryStatus == nil {
                    await manager.refreshBattery()
                }
            }
        }
    }

    private var accentColor: Color {
        guard let status = manager.batteryStatus else { return .secondary }
        if status.isCharging { return .green }
        return status.level <= 20 ? .red : .primary
    }

    private var batterySymbol: String {
        guard let status = manager.batteryStatus else { return "battery.50percent" }
        if status.isCharging { return "battery.100percent.bolt" }
        switch status.level {
        case ...10: return "battery.0percent"
        case ...30: return "battery.25percent"
        case ...60: return "battery.50percent"
        case ...85: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
