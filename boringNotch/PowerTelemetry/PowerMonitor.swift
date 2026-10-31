import Defaults
import SwiftUI

extension Defaults.Keys {
    static let showPowerUsage = Key<Bool>("showPowerUsage", default: true)
}

@MainActor
final class PowerMonitor: ObservableObject {
    static let shared = PowerMonitor()
    @Published private(set) var reading: PowerReading?
    private var consumers: Set<UUID> = []
    private var pollingTask: Task<Void, Never>?

    private init() {}

    /// Sample only while an on-screen power label or detail view needs a value.
    func setActive(_ active: Bool, for id: UUID) {
        if active { consumers.insert(id) } else { consumers.remove(id) }
        guard !consumers.isEmpty else {
            pollingTask?.cancel()
            pollingTask = nil
            reading = nil
            return
        }
        guard pollingTask == nil else { return }
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                let data = await XPCHelperClient.shared.readPowerTelemetry()
                guard !Task.isCancelled, let self else { return }
                self.reading = data.flatMap(PowerReading.decodeSample)
                try? await Task.sleep(for: .seconds(2))
            }
        }
    }

    static func formatted(_ watts: Double?, estimated: Bool = false) -> String {
        guard let watts, watts.isFinite else { return "—" }
        return (estimated ? "≈ " : "") + String(format: "%.1f W", watts)
    }
}

struct PowerCompactView: View {
    @ObservedObject private var monitor = PowerMonitor.shared
    @State private var consumerID = UUID()

    var body: some View {
        Group {
            if let reading = monitor.reading {
                let value = PowerMonitor.formatted(reading.displayedWatts, estimated: reading.isDisplayedEstimate)
                if reading.isCharging {
                    Text("Charging \(value)")
                } else {
                    Text("Power \(value)")
                }
            } else {
                Text("Power —")
            }
        }
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.white.opacity(0.8))
        .lineLimit(1)
        .fixedSize(horizontal: true, vertical: false)
        .help("Charging shows power entering the battery; otherwise this shows whole-Mac power use.")
        .onAppear { monitor.setActive(true, for: consumerID) }
        .onDisappear { monitor.setActive(false, for: consumerID) }
    }
}

struct PowerDetailsView: View {
    @ObservedObject private var monitor = PowerMonitor.shared
    @State private var consumerID = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LabeledContent("Charging power") {
                Text(verbatim: PowerMonitor.formatted(chargingWatts,
                    estimated: monitor.reading.map { $0.isCharging && $0.batterySource.isEstimate } ?? false))
            }
            LabeledContent("System power") {
                Text(verbatim: PowerMonitor.formatted(monitor.reading?.systemWatts,
                                                     estimated: monitor.reading?.systemSource.isEstimate ?? false))
            }
            LabeledContent("Adapter input") {
                Text(verbatim: PowerMonitor.formatted(monitor.reading?.adapterWatts))
            }
            if let reading = monitor.reading {
                if reading.systemSource.isEstimate || (reading.isCharging && reading.batterySource.isEstimate) {
                    Text("≈ indicates an estimate from battery readings or power balance.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if reading.systemSource == .telemetry || (reading.isCharging && reading.batterySource == .telemetry) {
                    Text("Using system telemetry; readings may update more slowly.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text("Power data is temporarily unavailable.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .monospacedDigit()
        .onAppear { monitor.setActive(true, for: consumerID) }
        .onDisappear { monitor.setActive(false, for: consumerID) }
    }

    private var chargingWatts: Double? {
        guard let reading = monitor.reading else { return nil }
        guard reading.isCharging else { return 0 }
        return reading.batteryWatts.flatMap { $0 >= 0 ? $0 : nil }
    }
}
