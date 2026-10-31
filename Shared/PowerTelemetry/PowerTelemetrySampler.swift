import Foundation
import IOKit
import IOKit.ps

/// Read-only hardware sampling. Used by the existing XPC service, with no root helper.
final class PowerTelemetrySampler {
    private let lock = NSLock()
    private var smc: SMCReader?
    private var smcFailures = 0

    func sample() -> PowerReading? {
        lock.lock()
        defer { lock.unlock() }

        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        var dictionary: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &dictionary, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let properties = dictionary?.takeRetainedValue() as? [String: Any] else { return nil }

        if smc == nil { smc = SMCReader() }
        let system = smc?.double("PSTR")
        let adapter = smc?.double("PDTR")
        let current = smc?.double("B0AC")
        let voltage = smc?.double("B0AV")
        var battery: Double?
        if let current, let voltage,
           current.isFinite, abs(current) < 40000,
           voltage.isFinite, (1000...30000).contains(voltage) {
            battery = current * voltage / 1_000_000
        }

        if system == nil && adapter == nil && battery == nil {
            smcFailures += 1
            if smcFailures >= 3 {
                if smc?.reconnect() != true { smc = nil }
                smcFailures = 0
            }
        } else { smcFailures = 0 }

        let state = powerSourceState()
        return PowerReadingBuilder.make(properties: properties,
                                        externalConnected: state?.external,
                                        charging: state?.charging,
                                        smcSystem: system, smcAdapter: adapter, smcBattery: battery)
    }

    private func powerSourceState() -> (external: Bool, charging: Bool)? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let info = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  (info[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType else { continue }
            return (info[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue,
                    info[kIOPSIsChargingKey] as? Bool ?? false)
        }
        return nil
    }
}
