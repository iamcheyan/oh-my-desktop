pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Host hardware metadata.
 *
 * `screenHasNotch` reports whether any attached screen is a MacBook panel
 * with a physical camera notch. The bar grows taller over the notch so the
 * cutout stays covered; notch-less hosts keep the slimmer bar.
 *
 * Detection: Apple host marker plus panel aspect ratio. Notched Apple panels
 * are taller than 16:10 (~1.54 — the extra rows flank the cutout) while
 * non-notched ones are exactly 16:10 (1.6). Gating on the Apple marker keeps
 * 3:2 panels from other vendors from matching.
 *
 * The marker comes from SUMIKA_HOST_APPLE, exported synchronously by
 * scripts/quickshell before the QML engine starts (singletons load lazily, so
 * an async read here would race the first height evaluation). The Process
 * below re-reads /proc/device-tree/model only as a fallback for bare `qs -p`
 * runs that bypass the wrapper.
 */
Singleton {
    id: root

    // e.g. "Apple MacBook Pro (14-inch, M1 Max, 2021)"; empty on non-Apple hosts.
    property string deviceModel: ""

    property string envApple: Quickshell.env("SUMIKA_HOST_APPLE") ?? ""
    property bool isAppleHost: root.envApple !== ""
        ? root.envApple === "1"
        : root.deviceModel.startsWith("Apple")

    // 1.595 sits between 16:10 (1.6) and notch panels (~1.54) with margin
    // for scale rounding.
    readonly property bool screenHasNotch: root.isAppleHost && Quickshell.screens.some(screen =>
        screen.width > 0 && screen.height > 0 && (screen.width / screen.height) < 1.595
    )

    Process {
        running: true
        command: ["bash", "-c", "cat /proc/device-tree/model 2>/dev/null || true"]
        stdout: StdioCollector {
            onStreamFinished: root.deviceModel = text.replace(/\0/g, "").trim()
        }
    }
}
