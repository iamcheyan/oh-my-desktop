# Bluetooth Keyboard Pairing on Asahi Linux

## Problem

On Apple Silicon (asahi Linux), Bluetooth keyboards that use Legacy Pairing
(e.g. MINILA-R Convertible) fail to connect after entering the PIN code.
The pairing appears to succeed (bonding completes), but the connection is
immediately dropped.

## Symptoms

1. Keyboard is discovered, pairing code is entered and accepted.
2. Connection drops immediately after pairing completes.
3. `bluetoothctl info <addr>` shows `Paired: yes`, `Bonded: yes`, but
   `Connected: no` and `Trusted: no`.

## Root Cause

Asahi's Bluetooth controller (`hci0`) does not support the **Set Device Flags**
HCI command with the wake-allowed flag (`0x3`). It only supports flag `0x6`.

BlueZ calls `Set Device Flags` after pairing to mark the device as
wake-capable. The kernel rejects the command:

```
bluetoothd: src/device.c:set_wake_allowed_complete() Set device flags return status: Invalid Parameters
kernel: Bluetooth: hci0: Bad flag given (0x3) vs supported (0x6)
```

This failure causes the post-pairing connection sequence to abort, and the
device is disconnected with reason code 19:

```
bluetoothd: src/bearer.c:btd_bearer_disconnected() Unknown disconnection value: 19
bluetoothd: src/device.c:device_disconnected() Unknown disconnection value: 19
```

## Fix

The device **does pair and bond successfully** — it just doesn't auto-connect
afterwards because `Trusted` was not set and the wake-flags failure aborts the
connection.

### Manual fix via bluetoothctl

```sh
# After the pairing attempt fails (device shows Paired:yes, Connected:no):
bluetoothctl trust <addr>
bluetoothctl connect <addr>
```

Setting `Trusted: yes` before connecting allows the device to reconnect
without re-pairing. Once trusted, the keyboard should auto-connect on
subsequent sessions.

### Verifying the keyboard is working

```sh
bluetoothctl info <addr>
# Should show:
#   Paired: yes
#   Bonded: yes
#   Trusted: yes
#   Connected: yes

# Check that the HID input device was registered:
journalctl --since "1 min ago" | grep -i "uhid\|hid-generic\|input:.*keyboard"
```

## Affected Devices

| Device | Pairing Type | Vendor:Product |
|--------|-------------|-----------------|
| MINILA-R Convertible | Legacy (BR/EDR) | `0a5c:8502` |
| GuoのMagic Keyboard | LE | `004c:029c` |

LE-paired devices (e.g. Apple Magic Keyboard) are not affected because they
don't trigger the wake-flags path in the same way.

## keyd Considerations

The `keyd` daemon ignores Bluetooth keyboards by default because
`keyboard-remap/keyd.generated.conf` only lists specific device IDs in the
`[ids]` section. To enable key remapping on a Bluetooth keyboard, add its
vendor:product ID:

```ini
[ids]
k:0c45:22b8
k:0a5c:8502
```

## Environment

- OS: Fedora 44 aarch64 (asahi Linux)
- BlueZ: 5.86
- Kernel Bluetooth: asahi hci0 (Apple Silicon Bluetooth controller)