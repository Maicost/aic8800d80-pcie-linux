# AIC8800D80 over PCIe on Linux (WiFi 6 + Bluetooth): DKMS, kernels 6.13 to 7.3

Out-of-tree driver for AICSemi **AIC8800D80** combo cards that expose WiFi on **PCIe
`a69c:8d80`** and Bluetooth on a companion USB device (`a69c:8d84`, which becomes
`a69c:8d85` once the firmware is running). Sold as UGREEN CM958 and several no-name
"WiFi 6 + BT 5.x" PCIe cards.

Tested on Fedora 44, kernels 7.2.10 to 7.3.3, gcc 16. No in-tree driver exists.

> Portuguese work log with the full debugging history: [NOTAS.pt-BR.md](NOTAS.pt-BR.md).

## What is in here

- `src/`: vendor driver 6.4.3.0 (UGREEN CM958 package, 2025-07-29) with every patch below
  already applied, plus the firmware files the driver loads.
- `patches/`: the same changes as individual patches against the vendor tree.

| Patch | What it does |
|---|---|
| 0001 to 0006 | From the AUR package [`aic8800d80-pcie-dkms`](https://aur.archlinux.org/packages/aic8800d80-pcie-dkms): kernel 6.13+, PCI modalias, logging, bluez, 7.1 and 7.2 compat |
| 0007 | Fixes a kernel oops on `rmmod`/suspend (tasklet rescheduled by the IRQ handler after `rwnx_hw` was freed) |
| 0008 | Kernel 7.3 cfg80211 API (cookies passed by value, `probe_peer`, `link_id` in `cfg80211_probe_status`), selected by **reading the kernel header at build time** instead of `KERNEL_VERSION` checks, so backported kernels pick the right branch |

Two more changes live only in `src/` (not split into patch files):

- `aicwf_pcie_init` restores **BAR0** when the PCI config space reads a different value from
  what the kernel assigned. Without firmware the chip's bootrom watchdog resets the card
  every ~25 minutes, and that reset zeroes BAR0. Symptom: probe fails with
  `pci set&tst fail` and an AER `UnsupReq`.
- `CONFIG_COUNTRY_CODE = "BR"` in `src/drivers/aic8800/aic8800_fdrv/Makefile`. **Change it to
  your country.** The wiphy is self-managed and ignores `iw reg set`; with `"00"` every
  channel is no-IR and the card scans but never associates.

## Install

Needs `dkms`, `rsync`, and the kernel headers (`kernel-devel` on Fedora).

```sh
sudo ./2_install_pcie.sh     # firmware + DKMS; blacklists autoload while you test
sudo ./3_test_load_pcie.sh   # loads the module once, kernel log goes to logs/
sudo ./4_enable_autoload.sh  # once stable: autoload at boot + suspend hook
```

`1_setup_kdump.sh` is optional but recommended before the first load: if the driver panics
you get a dump in `/var/crash` instead of a frozen machine.

After a kernel update DKMS rebuilds on its own. If you change the source, or a new kernel
ended up without the module:

```sh
sudo ./6_update_dkms.sh
```

## Notes

- **Bluetooth** works with the generic `btusb` once the WiFi module has loaded the firmware
  (the USB device re-enumerates as `8d85`). The vendor `aic_btusb` is built but blacklisted.
  No WiFi module means no Bluetooth either.
- **Suspend**: the driver does not survive suspend while loaded. The hook
  `aic8800d80-sleep-hook` unloads it before sleep, reloads it after, and restarts
  `wpa_supplicant` (which otherwise stays bound to the old netdev and fails every scan).
  The interface name `wlp3s0` is hardcoded there and in `5_test_patch_0007.sh`.
- **NetworkManager MAC randomization** makes this FullMAC driver recreate the interface.
  If scans come back empty, set `wifi.scan-rand-mac-address=no` and
  `wifi.cloned-mac-address=permanent`.
- **Cable and WiFi on the same subnet**: apparent packet loss was ARP flux; fixed with
  `net.ipv4.conf.all.arp_ignore=1` and `arp_announce=2`.
- The card is 1x1; expect about 280 Mbit/s on 5 GHz VHT80.

## A new kernel broke the build?

```sh
dkms status aic8800-pcie
grep -nE 'error' /var/lib/dkms/aic8800-pcie/6.4.3.0/build/make.log
```

Recovery if a boot hangs with the module autoloaded: add
`modprobe.blacklist=aic8800D80_fdrv,aic_btusb` to the kernel command line in GRUB.

## License and credits

The driver source is GPL (`MODULE_LICENSE("GPL")`), copyright AICSemi / RivieraWaves. The
firmware binaries in `src/fw/` are AICSemi's, redistributed unmodified from the vendor
package. Patches 0001 to 0006 come from the AUR package maintainers. No warranty: this is an
out-of-tree driver that has caused kernel panics during development.
