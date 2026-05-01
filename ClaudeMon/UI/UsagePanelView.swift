import SwiftUI

struct UsagePanelView: View {
    @EnvironmentObject var store: UsageStore
    var onOpenSettings: () -> Void
    var onQuit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            if let err = store.lastError {
                ErrorBanner(message: err, retry: { Task { await store.refresh() } })
            }

            section("Plan usage limits") {
                UsageRowView(label: "Current session", bucket: store.snapshot?.fiveHour)
            }

            section("Weekly limits") {
                UsageRowView(label: "All models", bucket: store.snapshot?.sevenDay)
                UsageRowView(label: "Sonnet only", bucket: store.snapshot?.sevenDaySonnet)
                if let opus = store.snapshot?.sevenDayOpus {
                    UsageRowView(label: "Opus only", bucket: opus)
                }
                if let omelette = store.snapshot?.sevenDayOmelette {
                    UsageRowView(label: "Claude Design", bucket: omelette)
                }
            }

            if let extra = store.snapshot?.extraUsage, extra.isEnabled {
                section("Extra usage") {
                    extraUsageView(extra)
                }
            }

            Divider()

            HStack {
                Text(footerText).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Button(action: { Task { await store.refresh() } }) {
                    Image(systemName: "arrow.clockwise")
                }.buttonStyle(.borderless)
                Button("Settings…", action: onOpenSettings).buttonStyle(.borderless)
                Button("Quit", action: onQuit).buttonStyle(.borderless)
            }
        }
        .padding(14)
        .frame(width: 360)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).bold()
            content()
        }
    }

    private func extraUsageView(_ extra: ExtraUsage) -> some View {
        let pct = extra.utilizationInt
        let symbol = extra.currency == "USD" ? "$" : ""
        let used = String(format: "%.2f", extra.usedCredits / 100.0)
        let limit = String(format: "%.2f", extra.monthlyLimit / 100.0)
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(symbol)\(used) used")
                Spacer()
                Text("\(pct)% used").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value: Double(min(pct, 100)) / 100.0)
                .tint(pct >= 100 ? .red : .accentColor)
            Text("Monthly limit \(symbol)\(limit)")
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private var footerText: String {
        if store.isLoading { return "Updating…" }
        guard let t = store.lastUpdated else { return "Not yet updated" }
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return "Updated \(f.localizedString(for: t, relativeTo: Date()))"
    }
}

private struct ErrorBanner: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).font(.caption)
            Spacer()
            Button("Retry", action: retry).buttonStyle(.borderless)
        }
        .padding(8)
        .background(Color.yellow.opacity(0.15))
        .foregroundStyle(.primary)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
