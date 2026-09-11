//
//  A12Z.swift
//  melonx-a12z
//
//  This clone exists to run on exactly one chip: the Apple A12Z Bionic, i.e. the
//  2020 iPad Pro. It refuses to launch on anything else, on purpose.
//
//  Why refuse rather than just "prefer"? Because the A12Z failure everyone is chasing
//  is only interesting if a result is unambiguous. If this build can also run on an
//  A17, then "it worked" and "it didn't" stop being evidence about the A12Z - somebody
//  will inevitably test on the wrong device and report a result that means nothing.
//  A hard gate makes every report from this build an A12Z report.
//
//  What is actually special about A12Z, as far as anyone has established:
//
//    * It is Apple GPU family 5. Family 6 (A13) is where Metal gained Tier 2 argument
//      buffers and SIMD-group functions in fragment shaders. So A12Z is Tier 1:
//      roughly 96/128 textures and 16 samplers, against family 6's effectively
//      unlimited bindless.
//    * It has 6 GB of RAM. Its family-5 siblings - A12 (iPhone XS) and A12X (2018
//      iPad Pro) - have 4 GB.
//
//  Those two facts together are the most plausible explanation for why the bug looks
//  chip-specific when it is probably family-specific: A12Z is the ONLY Tier 1 device
//  with enough memory that anyone seriously tries to run a Switch emulator on it. The
//  others run out of memory long before they can expose a GPU-tier problem, so nobody
//  attributes anything to the GPU. This is a hypothesis, not a finding.
//

import Foundation
import Metal
import SwiftUI
import UIKit

enum A12Z {

    /// The 2020 iPad Pro, the only shipping A12Z device.
    ///   iPad8,9  / iPad8,10  - iPad Pro 11" (2nd generation)
    ///   iPad8,11 / iPad8,12  - iPad Pro 12.9" (4th generation)
    ///
    /// Deliberately NOT including iPad8,1...iPad8,8: those are the 2018 iPad Pro, which
    /// is A12X. A12X and A12Z are the same die with one extra GPU core enabled on the Z,
    /// so they are both GPU family 5 - but the 2018 model has 4 GB rather than 6 GB, and
    /// mixing them would blur exactly the distinction this build exists to test.
    static let supportedIdentifiers: Set<String> = [
        "iPad8,9", "iPad8,10", "iPad8,11", "iPad8,12",
    ]

    /// Raw `hw.machine`, e.g. "iPad8,11". Read from uname directly and deliberately:
    /// anything that prefers a MobileGestalt marketing name ("iPad Pro (12.9-inch)")
    /// cannot distinguish the 2018 A12X model from the 2020 A12Z one, which is the
    /// distinction this whole build rests on.
    static var hardwareIdentifier: String = {
        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: info.machine)) {
                String(cString: $0)
            }
        }
    }()

    /// Metal's own name for the GPU, e.g. "Apple A12Z GPU". Used as a second opinion:
    /// the identifier list above can go stale, a GPU name check cannot mistake an A12Z
    /// for an A13, and a simulator or a future device would fail both.
    static var gpuName: String {
        MTLCreateSystemDefaultDevice()?.name ?? "unknown"
    }

    static var isA12Z: Bool {
        if supportedIdentifiers.contains(hardwareIdentifier) { return true }
        // Fallback for anything the list does not know about that still reports A12Z.
        return gpuName.uppercased().contains("A12Z")
    }

    /// Metal argument buffer tier. Tier 2 requires Apple GPU family 6 (A13+); A12Z is
    /// family 5 and must report tier1 here. If this ever reports tier2 on an A12Z, the
    /// entire argument-buffer hypothesis is wrong and should be abandoned.
    static var argumentBuffersTier: String {
        guard let device = MTLCreateSystemDefaultDevice() else { return "no Metal device" }
        switch device.argumentBuffersSupport {
        case .tier1: return "tier1"
        case .tier2: return "tier2"
        @unknown default: return "unknown"
        }
    }

    static var supportsAppleGPUFamily6: Bool {
        guard let device = MTLCreateSystemDefaultDevice() else { return false }
        if #available(iOS 13.0, *) {
            return device.supportsFamily(.apple6)
        }
        return false
    }

    /// Everything worth knowing about this device in one string, for the launch log and
    /// for anything a tester pastes into a bug report.
    static var report: String {
        let device = MTLCreateSystemDefaultDevice()
        var lines: [String] = []
        lines.append("hardware:            \(hardwareIdentifier)")
        lines.append("system:              \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)")
        lines.append("GPU:                 \(gpuName)")
        lines.append("argument buffers:    \(argumentBuffersTier)")
        lines.append("Apple GPU family 6:  \(supportsAppleGPUFamily6)")
        if let device {
            lines.append("max buffer length:   \(device.maxBufferLength / (1024 * 1024)) MB")
            if #available(iOS 13.0, *) {
                lines.append("family apple5:       \(device.supportsFamily(.apple5))")
                lines.append("family apple7:       \(device.supportsFamily(.apple7))")
            }
            lines.append("has unified memory:  \(device.hasUnifiedMemory)")
        }
        lines.append("physical memory:     \(ProcessInfo.processInfo.physicalMemory / (1024 * 1024)) MB")
        lines.append("is A12Z:             \(isA12Z)")
        return lines.joined(separator: "\n")
    }
}

/// Shown instead of the emulator when this build finds itself on the wrong device.
struct WrongDeviceView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This build is A12Z only")
                .font(.title2.bold())
            Text("""
                 This is a deliberately restricted clone of MeloNX, built to investigate \
                 why the emulator fails on the A12Z (2020 iPad Pro) and nowhere else.

                 It refuses to run on other devices on purpose. If it ran everywhere, a \
                 report of "it worked" would not tell anyone anything about the A12Z.

                 Use a normal MeloNX build on this device.
                 """)
                .font(.callout)
            Divider()
            Text("This device")
                .font(.headline)
            Text(A12Z.report)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)
        }
        .padding()
    }
}
