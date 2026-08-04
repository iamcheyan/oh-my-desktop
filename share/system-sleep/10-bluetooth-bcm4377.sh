#!/bin/bash
# Reload the BCM4377 Bluetooth module after resume.
#
# On Apple Silicon (Asahi) the Broadcom BCM4377 controller's firmware
# enters a bad state after suspend: connect attempts crash the controller
# (Authentication Failed 0x05, command tx timeout -110). Restarting
# bluetoothd or toggling rfkill is not enough — the kernel module must be
# reloaded so the firmware is re-initialised. After reload, BlueZ
# auto-reconnects trusted/paired devices.
case "$1/$2" in
    post/*)
        /usr/sbin/modprobe -r hci_bcm4377 2>/dev/null || true
        sleep 0.5
        /usr/sbin/modprobe hci_bcm4377 2>/dev/null || true
        ;;
esac
