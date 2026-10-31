import Foundation

enum PowerDataSource: String, Codable, Sendable {
    case smc, telemetry, batteryEstimate, derived, unavailable

    var isEstimate: Bool { self == .batteryEstimate || self == .derived }
}

struct PowerReading: Codable, Equatable, Sendable {
    let isPluggedIn: Bool
    let isCharging: Bool
    let batteryWatts: Double?
    let systemWatts: Double?
    let adapterWatts: Double?
    let batterySource: PowerDataSource
    let systemSource: PowerDataSource
    let sampledAt: Date

    var displayedWatts: Double? {
        if isCharging {
            // A transient negative current must not appear as positive charging.
            guard let batteryWatts, batteryWatts >= 0 else { return nil }
            return batteryWatts
        }
        return systemWatts
    }

    var isDisplayedEstimate: Bool {
        isCharging ? batterySource.isEstimate : systemSource.isEstimate
    }

    static func decodeSample(_ data: Data) -> PowerReading? {
        guard let reading = try? JSONDecoder().decode(Self.self, from: data),
              [reading.batteryWatts, reading.systemWatts, reading.adapterWatts]
                .compactMap({ $0 }).allSatisfy({ $0.isFinite && abs($0) < 1000 }),
              reading.systemWatts.map({ $0 >= 0 }) ?? true,
              reading.adapterWatts.map({ $0 >= 0 }) ?? true
        else { return nil }
        return reading
    }
}

/// Pure conversion and fallback rules; independent of sensors and the UI.
enum PowerReadingBuilder {
    static func make(
        properties: [String: Any],
        externalConnected: Bool? = nil,
        charging: Bool? = nil,
        smcSystem: Double? = nil,
        smcAdapter: Double? = nil,
        smcBattery: Double? = nil,
        now: Date = Date()
    ) -> PowerReading {
        let telemetry = properties["PowerTelemetryData"] as? [String: Any] ?? [:]
        let external = externalConnected ?? (properties["ExternalConnected"] as? Bool ?? false)
        let isCharging = external && (charging ?? (properties["IsCharging"] as? Bool ?? false))

        var battery = valid(smcBattery, signed: true)
        var batterySource: PowerDataSource = battery == nil ? .unavailable : .smc
        // Instant current responds sooner than the slowly republished telemetry,
        // which can still contain zero after disconnecting an adapter.
        if battery == nil,
           let millivolts = number(properties["Voltage"]), (1000...30000).contains(millivolts),
           let milliamps = signedNumber(properties["InstantAmperage"] ?? properties["Amperage"]),
           abs(milliamps) < 40000 {
            battery = valid(millivolts * milliamps / 1_000_000, signed: true)
            if battery != nil { batterySource = .batteryEstimate }
        }
        if battery == nil, let mw = signedNumber(telemetry["BatteryPower"]) {
            battery = valid(mw / 1000, signed: true)
            if battery != nil { batterySource = .telemetry }
        }

        let adapter: Double? = external
            ? (valid(smcAdapter) ?? number(telemetry["SystemPowerIn"]).flatMap { valid($0 / 1000) })
            : 0
        var system = valid(smcSystem, allowZero: false)
        var systemSource: PowerDataSource = system == nil ? .unavailable : .smc

        if system == nil, !external, let battery, battery < 0 {
            system = -battery
            systemSource = .batteryEstimate
        }
        if system == nil, let mw = number(telemetry["SystemLoad"]), let value = valid(mw / 1000, allowZero: false) {
            system = value
            systemSource = .telemetry
        }
        if system == nil, external, let adapter, let battery,
           let value = valid(adapter - battery, allowZero: false) {
            system = value
            systemSource = .derived
        }

        return PowerReading(isPluggedIn: external, isCharging: isCharging,
                            batteryWatts: battery, systemWatts: system, adapterWatts: adapter,
                            batterySource: batterySource, systemSource: systemSource, sampledAt: now)
    }

    static func number(_ raw: Any?) -> Double? {
        guard let number = raw as? NSNumber else { return nil }
        let value = number.doubleValue
        return value.isFinite ? value : nil
    }

    /// IORegistry may encode a negative current as a two's-complement UInt32/64.
    static func signedNumber(_ raw: Any?) -> Double? {
        guard let number = raw as? NSNumber else { return nil }
        let value = number.doubleValue
        guard value.isFinite else { return nil }
        if value > Double(Int32.max) {
            let bits = number.uint64Value
            return bits > UInt64(UInt32.max)
                ? Double(Int64(bitPattern: bits))
                : Double(Int32(bitPattern: UInt32(bits)))
        }
        return value
    }

    private static func valid(_ value: Double?, signed: Bool = false, allowZero: Bool = true) -> Double? {
        guard let value, value.isFinite, abs(value) < 1000,
              signed || value >= 0, allowZero || value > 0 else { return nil }
        return value
    }
}
