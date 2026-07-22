# Wi-Fi Connect Flow

This document defines the current connection behavior shared by the bar and
network settings UI. It is a behavioral contract rather than a change log.

## Current Model

| Step | Behavior |
| --- | --- |
| Known SSID | `nmcli connection up` then fallback `device wifi connect` |
| Unknown open | `device wifi connect` immediately |
| Unknown secure | Show password UI **before** attempting |
| Password submit | Update profile PSK if exists, else `device wifi connect … password` |
| Secrets/auth fail | Re-open password UI with humanized error |
| Other fail | Show error, do not force password UI |

Service state: `wifiConnectPhase` =
`idle | connecting | need_password | failed | success` plus
`wifiConnectMessage` / `lastConnectError`.

## UI Surfaces

- **Bar Wi-Fi popup** — connection header; **Wi-Fi** toggle + nearby list +
  password (grouped); divider; **Bluetooth** toggle alone. Full settings via
  the gear on each toggle (no bottom “Network settings…” footer).
- **Settings Network page** — two-column network center (no Bluetooth); same
  connect API; link details, diagnostics, saved profiles, advanced tools.
  Shared panel rules are in
  [`../settings/settings-layout-system.md`](../settings/settings-layout-system.md).

## Key Files

- `quickshell/services/Network.qml`
- `quickshell/services/network/WifiAccessPoint.qml`
- `quickshell/modules/bar/BarStatusPopup.qml` (`wifiContent`)
- `quickshell/modules/settings/pages/NetworkPage.qml`
