import SwiftUI

struct OnboardingView: View {
    @Bindable var setup: SetupModel
    @State private var showLog = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(setup.steps) { step in
                        StepRow(step: step, isBusy: setup.isRunning) {
                            Task { await setup.performAction(step.kind) }
                        } recheck: {
                            Task { await setup.refresh() }
                        }
                    }
                }
                .padding(16)
            }
            Divider()
            footer
        }
        .frame(minWidth: 520, minHeight: 620)
        .task { await setup.refresh() }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Image(systemName: setup.isComplete ? "checkmark.seal.fill" : "iphone.gen3.radiowaves.left.and.right")
                .font(.system(size: 34))
                .foregroundStyle(setup.isComplete ? .green : .blue)
                .symbolRenderingMode(.hierarchical)
            Text(setup.isComplete ? "Oops is set up 🎉" : "Set up Oops on your iPhone")
                .font(.title2.bold())
            Text(setup.isComplete
                 ? "Everything's ready. Oops is installed and running on \(setup.device?.name ?? "your iPhone")."
                 : "A quick guided setup. I detect what's done automatically — you only do the few steps that need you.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            ProgressView(value: Double(setup.completedCount), total: Double(setup.steps.count))
                .frame(maxWidth: 320)
                .padding(.top, 4)
        }
        .padding(20)
    }

    private var footer: some View {
        VStack(spacing: 8) {
            HStack {
                Button {
                    Task { await setup.refresh() }
                } label: {
                    Label("Re-check all", systemImage: "arrow.clockwise")
                }
                .disabled(setup.isRunning)

                Spacer()

                if setup.isRunning { ProgressView().controlSize(.small) }

                Button(showLog ? "Hide log" : "Show log") { showLog.toggle() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
            }
            if showLog {
                ScrollView {
                    Text(setup.log.isEmpty ? "No activity yet." : setup.log)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(height: 120)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(16)
    }
}

private struct StepRow: View {
    let step: SetupStep
    let isBusy: Bool
    let action: () -> Void
    let recheck: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            statusIcon
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title).font(.headline)
                Text(step.summary).font(.subheadline).foregroundStyle(.secondary)

                if !step.detail.isEmpty {
                    Text(step.detail)
                        .font(.caption)
                        .foregroundStyle(detailColor)
                }

                if isActive, !step.instructions.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        ForEach(Array(step.instructions.enumerated()), id: \.offset) { i, line in
                            Label(line, systemImage: "\(i + 1).circle")
                                .font(.caption)
                                .labelStyle(.titleAndIcon)
                        }
                    }
                    .padding(.top, 4)
                }

                if isActive {
                    HStack(spacing: 8) {
                        if let title = step.actionTitle {
                            Button(title, action: action).buttonStyle(.borderedProminent)
                        }
                        Button("Re-check", action: recheck)
                    }
                    .controlSize(.small)
                    .padding(.top, 6)
                    .disabled(isBusy && !isRunningThisStep)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isActive ? Color.accentColor.opacity(0.5) : .clear, lineWidth: 1))
    }

    private var isActive: Bool {
        switch step.state { case .needsAction, .failed, .running: return true; default: return false }
    }
    private var isRunningThisStep: Bool { step.state == .running }

    @ViewBuilder private var statusIcon: some View {
        switch step.state {
        case .pending: Image(systemName: "circle").foregroundStyle(.tertiary)
        case .checking, .running: ProgressView().controlSize(.small)
        case .needsAction: Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.orange)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    private var detailColor: Color {
        switch step.state {
        case .done: return .green
        case .failed: return .red
        case .needsAction: return .orange
        default: return .secondary
        }
    }

    private var rowBackground: some ShapeStyle {
        isActive ? AnyShapeStyle(.background.secondary) : AnyShapeStyle(.background)
    }
}
