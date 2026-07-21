# Wi-Fi Connect Flow

Date: 2026-07-15

## Problems Fixed

1. **No password UI** — `Network.qml` set `askingPassword` on APs, but
   `NetworkPage.qml` never rendered a password field. Unknown secure networks
   looked like dead clicks.
2. **Any failure opened “password mode”** — `onExited` set
   `askingPassword = (exitCode !== 0)` for every error, including “not found”
   and timeouts.
3. **Weak feedback** — no lasting phase/message for connecting / failed /
   success.
4. **Bar popup was status-only** — connect required opening Settings.

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
  See `docs/network-settings-layout.md`.

## Key Files

- `quickshell/services/Network.qml`
- `quickshell/services/network/WifiAccessPoint.qml`
- `quickshell/modules/bar/BarStatusPopup.qml` (`wifiContent`)
- `quickshell/modules/settings/pages/NetworkPage.qml`
