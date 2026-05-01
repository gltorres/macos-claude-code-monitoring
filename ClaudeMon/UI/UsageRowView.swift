import SwiftUI

struct UsageRowView: View {
    let label: String
    let bucket: Bucket?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.body)
                    Text(resetSubtitle).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(percentLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: barValue)
                .progressViewStyle(.linear)
                .tint(barColor)
        }
    }

    private var barValue: Double {
        let raw = bucket?.utilization ?? 0
        let clamped = max(0, min(raw, 100))
        return Double(clamped) / 100.0
    }

    private var barColor: Color {
        guard let p = bucket?.utilization else { return .gray }
        if p >= 90 { return .red }
        if p >= 80 { return .orange }
        return .accentColor   // matches blue in the screenshot
    }

    private var percentLabel: String {
        bucket.map { "\($0.utilizationInt)% used" } ?? "—"
    }

    private var resetSubtitle: String {
        guard let resetsAt = bucket?.resetsAt else { return "No data yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return "Resets " + formatter.localizedString(for: resetsAt, relativeTo: Date())
    }
}
