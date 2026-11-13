#!/usr/bin/env bash
# Passo 4 (sudo): libera o autoload do WiFi PCIe no boot (pelo alias PCI a69c:8d80).
# Mantem aic_btusb em blacklist (o btusb generico cuida do BT da placa) e mantem o
# omit_drivers do dracut (modulo fora do initramfs; o udev carrega do rootfs, mais tarde).
# Instala tambem o hook de suspend (descarrega antes de dormir, recarrega ao acordar).
set -euo pipefail
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
cat > /etc/modprobe.d/aic8800-pcie.conf <<'CONF'
# AIC8800D80 PCIe: WiFi = aic8800D80_fdrv (autoload pelo alias PCI).
# BT da placa funciona com o btusb generico; o aic_btusb do fabricante fica desligado.
blacklist aic_btusb
CONF
rm -f /etc/modprobe.d/aic8800-pcie-test.conf
install -m755 "$HERE/aic8800d80-sleep-hook" /usr/lib/systemd/system-sleep/aic8800d80
echo "autoload liberado. Teste real: proximo reboot. Rollback: recriar o blacklist ou"
echo "no GRUB: modprobe.blacklist=aic8800D80_fdrv"
