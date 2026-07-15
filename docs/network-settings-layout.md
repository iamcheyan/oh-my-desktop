# Network Settings Layout

Date: 2026-07-15

## Goal

Turn the Settings **Network** page into a Wi‑Fi / Ethernet center:

- Remove Bluetooth (owned by the Bluetooth bar popup + its settings entry).
- Two-column layout: **connect on the left**, **link details + tools on the right**.
- Share the same connect / password state machine as the bar popup (`Network.qml`).

## Layout

```text
wide (≥980)
├── left · Connect
│   ├── hero (status + radio + scan)
│   ├── available networks (+ password)
│   └── saved profiles (forget / autoconnect)
└── right · Link & tools
    ├── current link (IP, DNS, band, rates)
    ├── diagnostics (gateway / internet RTT)
    ├── suggested saved (signal + band heuristic)
    └── advanced (firewall summary, nm tools)

footer: Close
```

## Helpers

| Script | Purpose |
| --- | --- |
| `bin/omd-network-link-details` | device, IPv4, gateway, DNS, freq, band, bitrates, dBm |
| `bin/omd-network-diag` | ping gateway + 1.1.1.1 |
| `bin/omd-network-firewall` | firewalld / ufw / nft summary |

## Files

- `quickshell/modules/settings/pages/NetworkPage.qml`
- `quickshell/services/Network.qml`
- `docs/wifi-connect-flow.md` (connect protocol)
