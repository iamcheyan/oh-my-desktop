# Apple Fn Row Mode: Why It Resets on Reboot (initramfs Diagnosis)

This note records the full investigation of a recurring symptom: the MacBook
function row stops honoring the chosen mode after every reboot (F1 toggles
brightness instead of acting as F1).

Symptom report: "Fn 又不能锁定了，按 F1 是调整亮度而不是对应的 F1 键。我们之前改过这个设置。"

## TL;DR

The Fn-row mode (`hid_apple` `fnmode`) is applied at **module load time**.
On Asahi Linux the keyboard driver loads inside the **initramfs**, before the
real root is mounted — so the module options in `/etc/modprobe.d/` are ignored
unless they are baked into the initramfs. The config file was created **after**
the initramfs was generated, so every reboot loaded the module with the
kernel default `fnmode=3` (auto).

Fix = write the runtime value **and** rebuild the initramfs:

```sh
sudo sh -c 'echo 2 > /sys/module/hid_apple/parameters/fnmode'
sudo cp -a /boot/initramfs-6.19.14-400.asahi.fc44.aarch64+16k.img \
    /boot/initramfs-6.19.14-400.asahi.fc44.aarch64+16k.img.bak-fnmode
sudo dracut --force /boot/initramfs-6.19.14-400.asahi.fc44.aarch64+16k.img \
    6.19.14-400.asahi.fc44.aarch64+16k
```

The stored config is `/etc/modprobe.d/99-sumika-hid-apple.conf`
(`options hid_apple fnmode=2`); `bin/sumika-keyboard-function-row` (in the
keyboard-remap extension) writes it. After the fix, reboot loads the module
with `fnmode=2` directly — no longer stale.

## Background: what controls the Fn row

| Fact | Value |
|------|-------|
| Machine | MacBook (Asahi Linux M1), kernel 6.19.14-400.asahi.fc44.aarch64+16k |
| Keyboard | `Apple SPI Keyboard` (Bus `001c`, Phys `spi1.0`) |
| Transport driver | `spi_hid_apple` (+ `spi_hid_apple_of`) |
| HID driver bound | `/sys/bus/hid/drivers/apple` → **`hid_apple`** module |
| Fn mode knob | `/sys/module/hid_apple/parameters/fnmode` |
| Modes | `1` media-first · `2` F1–F12-first · `3` auto (default) |

The SPI keyboard is **not** a USB `hid_apple` device, but it binds the same
`apple` HID driver (module `hid_apple`), so `fnmode` still governs its Fn row.
(`lsmod` showing `hid_apple` refcount `0` is misleading — the device is bound
via the HID bus driver symlink `/sys/bus/hid/drivers/apple`, verified by
`readlink -f /sys/bus/hid/drivers/apple/module` → `/sys/module/hid_apple`.)

## Why the mode resets on every reboot

Timeline of the failing state (as observed 2026-08-10):

1. **2026-08-07 21:53** — `99-sumika-hid-apple.conf` created with
   `options hid_apple fnmode=2`. Runtime value was also written, so the Fn row
   behaved correctly **until the next reboot**.
2. **2026-06-16 11:28** — the running initramfs
   (`/boot/initramfs-6.19.14-400.asahi.fc44.aarch64+16k.img`) was generated,
   **before** the config file existed.
3. **Boot** — `hid_apple` loads during initramfs (kernel log:
   `apple 001C:05AC:0342.0001: SPI HID v3.52 Keyboard …`, ~1 s after boot,
   before the real root is mounted). The initramfs copy of
   `etc/modprobe.d/` contains the distro blacklists but **not**
   `99-sumika-hid-apple.conf` → module loads with default `fnmode=3`.
4. **After boot** — `/etc/modprobe.d/` options only affect *future* module
   loads; the already-loaded module ignores them. Result: Fn row in `auto`
   mode every boot, "as if" the setting was lost.

Key insight: `hid_apple` is loaded in the initramfs because the keyboard
driver must be ready before the root filesystem is available (full-disk
encryption / early input on Asahi). Any `modprobe.d` option for a driver that
loads in the initramfs **must be rebuilt into the initramfs**.

## Investigation path (how this was found)

- Ruled out **keyd**: `/etc/keyd/*.conf` only remaps `muhenkan`; Fn behavior
  is kernel-side, not keyd.
- Ruled out a runtime rewrite: the sysfs parameter mtime updated at
  21:20:49 with no matching sudo/pkexec/journal entry. **Trap:** reading a
  sysfs parameter file refreshes its mtime (verified by `cat` + `stat`), so a
  fresh mtime does **not** prove a write.
- Identified the real device path: SPI keyboard (`spi_hid_apple`), then
  confirmed it binds `hid_apple` via the `apple` HID driver.
- Compared `initramfs` generation time (6/16) vs config creation (8/7), then
  listed the initramfs contents (`zstd -dc … | cpio -t`) under sudo:
  `usr/lib/modules/…/hid-apple.ko.xz` present, `99-sumika-hid-apple.conf`
  absent → module loads with defaults.

## Fix

### Immediate (until next reboot)

```sh
sudo sh -c 'echo 2 > /sys/module/hid_apple/parameters/fnmode'
cat /sys/module/hid_apple/parameters/fnmode   # → 2
```

### Persistent (rebuild initramfs)

```sh
# backup first
sudo cp -a /boot/initramfs-6.19.14-400.asahi.fc44.aarch64+16k.img \
    /boot/initramfs-6.19.14-400.asahi.fc44.aarch64+16k.img.bak-fnmode
# rebuild; dracut hostonly=yes picks up /etc/modprobe.d/*.conf
sudo dracut --force /boot/initramfs-6.19.14-400.asahi.fc44.aarch64+16k.img \
    6.19.14-400.asahi.fc44.aarch64+16k
```

### Verify

```sh
sudo sh -c 'zstd -dc /boot/initramfs-6.19.14-400.asahi.fc44.aarch64+16k.img \
  | cpio -t --quiet' | grep 99-.*hid-apple
# expect both:
#   etc/modprobe.d/99-omd-hid-apple.conf
#   etc/modprobe.d/99-sumika-hid-apple.conf
```

After the next reboot, confirm `/sys/module/hid_apple/parameters/fnmode` is
`2` at login and F1 acts as F1.

## Notes / caveats

- **Every future Fn-mode change must be followed by `dracut --force`**, or the
  change silently reverts at the next reboot. `sumika-keyboard-function-row
  set <mode>` writes the runtime value and `/etc/modprobe.d/99-sumika-hid-apple.conf`
  but does **not** rebuild the initramfs — it cannot run `dracut` unattended.
  This is a known gap; if a future session owns this path, either add an
  initramfs-rebuild step (root, requires user authorization) or document the
  reboot-loss behavior.
- A legacy `/etc/modprobe.d/99-omd-hid-apple.conf` (old `omd` namespace,
  same `fnmode=2` content) coexists and is harmless; it is also baked into the
  rebuilt initramfs.
- Backup image left at
  `/boot/initramfs-6.19.14-400.asahi.fc44.aarch64+16k.img.bak-fnmode` — remove
  once the new initramfs is confirmed good after a reboot.
- Kernel updates generate a fresh initramfs via dracut hooks; the modprobe
  config is picked up automatically at that point. The bug only occurs when
  the config is newer than the last initramfs build.

## Related

- [`keyboard-remap.md`](keyboard-remap.md) — "MacBook function row" section
  (see correction note below).
- `sumika-keyboard-function-row` — extension script
  (`~/.local/share/sumika-shell/extensions/keyboard-remap/bin/`), writes
  runtime value + `/etc/modprobe.d/99-sumika-hid-apple.conf`.
