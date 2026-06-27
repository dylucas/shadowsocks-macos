// CryptoAccelerator — Detect Apple Silicon hardware crypto capabilities

import Foundation

enum CryptoAccelerator {

    /// Detect the current Apple Silicon chip generation
    static func chipGeneration() -> ChipGeneration {
        // Read CPU type from sysctl
        var size = 0
        sysctlbyname("machdep.cpu.brand_string", nil, &size, nil, 0)
        var cpuBrand = [CChar](repeating: 0, count: size)
        sysctlbyname("machdep.cpu.brand_string", &cpuBrand, &size, nil, 0)
        let brandString = String(cString: cpuBrand)

        if brandString.contains("M4") { return .m4 }
        if brandString.contains("M3") { return .m3 }
        if brandString.contains("M2") { return .m2 }
        if brandString.contains("M1") { return .m1 }

        // Check for Apple Silicon in general
        var isARM = 0
        size = MemoryLayout<Int32>.size
        sysctlbyname("hw.optional.arm.FEAT_AES", &isARM, &size, nil, 0)

        if isARM != 0 { return .m1 } // Generic ARM with AES
        return .intel // x86_64 Intel Mac
    }

    /// Check if ARM AES hardware acceleration is available
    static func hasAESAcceleration() -> Bool {
        var hasAES = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.optional.arm.FEAT_AES", &hasAES, &size, nil, 0)
        return hasAES != 0
    }

    /// Check if ARM NEON is available
    static func hasNEON() -> Bool {
        var hasNEON = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.optional.neon", &hasNEON, &size, nil, 0)
        return hasNEON != 0
    }

    /// Check if ARM FEAT_SHA3 (used by BLAKE3) is available
    static func hasSHA3Acceleration() -> Bool {
        var hasSHA3 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname("hw.optional.arm.FEAT_SHA3", &hasSHA3, &size, nil, 0)
        return hasSHA3 != 0
    }

    /// Get a summary of available hardware acceleration features
    static func accelerationSummary() -> AccelerationSummary {
        AccelerationSummary(
            chip: chipGeneration(),
            hasAES: hasAESAcceleration(),
            hasNEON: hasNEON(),
            hasSHA3: hasSHA3Acceleration(),
            isARM: chipGeneration() != .intel
        )
    }
}

// MARK: - Types

enum ChipGeneration: String {
    case m1 = "Apple M1"
    case m2 = "Apple M2"
    case m3 = "Apple M3"
    case m4 = "Apple M4"
    case intel = "Intel (x86_64)"
}

struct AccelerationSummary {
    let chip: ChipGeneration
    let hasAES: Bool
    let hasNEON: Bool
    let hasSHA3: Bool
    let isARM: Bool

    /// Description for UI display
    var description: String {
        if !isARM {
            return "\(chip.rawValue) — 无 ARM 硬件加速"
        }

        var features: [String] = []
        if hasAES { features.append("AES") }
        if hasNEON { features.append("NEON") }
        if hasSHA3 { features.append("SHA3 (BLAKE3)") }

        let featureStr = features.isEmpty ? "无特殊加速" : features.joined(separator: " + ")
        return "\(chip.rawValue) — \(featureStr)"
    }
}
