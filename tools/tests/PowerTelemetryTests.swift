import Foundation

@main
struct PowerTelemetryTests {
    static func main() throws {
        let charging = PowerReadingBuilder.make(properties: ["ExternalConnected": true, "IsCharging": true],
                                               smcSystem: 16.5, smcAdapter: 46.7, smcBattery: 29.4)
        precondition(charging.displayedWatts == 29.4 && charging.isCharging && !charging.isDisplayedEstimate,
                     "Charging must display power entering the battery, rather than adapter input")
        let paused = PowerReadingBuilder.make(properties: ["ExternalConnected": true, "IsCharging": false],
                                             smcSystem: 12.3, smcAdapter: 12.8, smcBattery: 0)
        precondition(paused.displayedWatts == 12.3 && !paused.isCharging,
                     "An adapter connected with charging paused must show system use")
        let battery = PowerReadingBuilder.make(properties: ["ExternalConnected": false],
                                              smcSystem: 10.7, smcAdapter: 20, smcBattery: -11)
        precondition(battery.displayedWatts == 10.7 && battery.adapterWatts == 0,
                     "Battery use must prefer the system sensor and clear stale adapter readings")
        let overridden = PowerReadingBuilder.make(properties: ["ExternalConnected": true, "IsCharging": true],
                                                 externalConnected: false, charging: false, smcBattery: -9)
        precondition(!overridden.isCharging && overridden.displayedWatts == 9 && overridden.isDisplayedEstimate,
                     "Immediate power-source state must override slow registry flags")

        for rawCurrent in [NSNumber(value: -1500), NSNumber(value: UInt32(bitPattern: -1500)),
                           NSNumber(value: UInt64(bitPattern: -1500))] {
            let fallback = PowerReadingBuilder.make(properties: [
                "Voltage": 12000, "InstantAmperage": rawCurrent, "Amperage": 0,
                "PowerTelemetryData": ["BatteryPower": 0, "SystemLoad": 99999]
            ])
            precondition(fallback.systemWatts == 18 && fallback.batteryWatts == -18 && fallback.isDisplayedEstimate,
                         "Signed currents must yield watts; fresh discharge must override stale telemetry")
        }
        let batteryCharge = PowerReadingBuilder.make(properties: [
            "ExternalConnected": true, "IsCharging": true, "Voltage": 12000, "Amperage": 2500
        ])
        precondition(batteryCharge.displayedWatts == 30 && batteryCharge.isDisplayedEstimate,
                     "Battery current/voltage fallback must retain an estimate marker while charging")

        let telemetry = PowerReadingBuilder.make(properties: ["ExternalConnected": true, "PowerTelemetryData": [
            "SystemLoad": 13500, "SystemPowerIn": 14000, "BatteryPower": 0
        ]])
        precondition(telemetry.systemWatts == 13.5 && telemetry.adapterWatts == 14 && telemetry.systemSource == .telemetry,
                     "Registry milliwatts must be converted to watts")
        let balance = PowerReadingBuilder.make(properties: ["ExternalConnected": true], smcAdapter: 45, smcBattery: 30)
        precondition(balance.systemWatts == 15 && balance.isDisplayedEstimate,
                     "Adapter minus battery fallback must be marked as estimated")
        let unavailable = PowerReadingBuilder.make(properties: ["AdapterDetails": ["Watts": 100]],
                                                  smcSystem: .nan, smcAdapter: .infinity, smcBattery: 9999)
        precondition(unavailable.displayedWatts == nil && unavailable.systemSource == .unavailable,
                     "Never substitute adapter rated watts or invalid readings for measured power")
        let transition = PowerReadingBuilder.make(properties: ["ExternalConnected": true, "IsCharging": true], smcBattery: -4)
        precondition(transition.displayedWatts == nil, "A negative transition current cannot appear as positive charging")

        let encoded = try JSONEncoder().encode(charging)
        precondition(PowerReading.decodeSample(encoded) == charging, "XPC payload must survive a JSON round trip")
        precondition(PowerReading.decodeSample(Data("{}".utf8)) == nil, "Malformed XPC data must be rejected")
        var invalid = try JSONSerialization.jsonObject(with: encoded) as! [String: Any]
        invalid["systemWatts"] = -10
        let invalidData = try JSONSerialization.data(withJSONObject: invalid)
        precondition(PowerReading.decodeSample(invalidData) == nil,
                     "Negative system power in an XPC payload must be rejected")

        precondition(SMCReader.decode(bytes: [0, 0, 72, 65], type: "flt ") == 12.5)
        precondition(SMCReader.decode(bytes: [0xD0, 0x30], type: "ui16") == 12496)
        precondition(SMCReader.decode(bytes: [0x24, 0xFA], type: "si16") == -1500)
        precondition(SMCReader.decode(bytes: [], type: "flt ") == nil)
        precondition(SMCReader.decode(bytes: [0], type: "unknown") == nil)
        print("Power: charging, paused AC, discharge, signed currents, fallbacks, invalid data, XPC payload, and SMC decoding passed.")

        if CommandLine.arguments.contains("--probe") {
            let sampler = PowerTelemetrySampler()
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            for index in 0..<3 {
                if index > 0 { Thread.sleep(forTimeInterval: 2) }
                guard let reading = sampler.sample() else {
                    print("Live power sensors are unavailable on this machine.")
                    continue
                }
                print(String(decoding: try encoder.encode(reading), as: UTF8.self))
            }
        }
    }
}
