#!/usr/bin/env bash
# Passo 2 (sudo): instala firmware PCIe + modulos via DKMS (aic8800-pcie/6.4.3.0).
# NAO carrega nada e BLOQUEIA autoload no boot (blacklist + dracut omit) enquanto esta em teste.
# Firmware da USB em /lib/firmware/aic8800D80 e preservado (nomes nao colidem).
set -euo pipefail
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
SRC="$HERE/src"
NAME=aic8800-pcie; VER=6.4.3.0; K=$(uname -r)
install -d /lib/firmware/aic8800D80
install -m644 "$SRC"/fw/aic8800D80/* /lib/firmware/aic8800D80/
cat > /etc/modprobe.d/aic8800-pcie-test.conf <<'CONF'
# FASE DE TESTE: impede o udev de carregar a AIC PCIe sozinha no boot.
# Carregar a mao: sudo modprobe aic8800D80_fdrv   (blacklist nao bloqueia modprobe explicito)
# Quando estiver estavel, apague este arquivo.
blacklist aic8800D80_fdrv
blacklist aic_btusb
CONF
cat > /etc/dracut.conf.d/aic8800-pcie.conf <<'CONF'
# Nunca embutir os modulos da AIC no initramfs (fase de teste).
omit_drivers+=" aic8800D80_fdrv aic_btusb "
CONF
rm -rf "/usr/src/$NAME-$VER"; cp -a "$SRC" "/usr/src/$NAME-$VER"
dkms remove -m "$NAME" -v "$VER" --all >/dev/null 2>&1 || true
dkms add -m "$NAME" -v "$VER"
dkms build -m "$NAME" -v "$VER" -k "$K"
dkms install -m "$NAME" -v "$VER" -k "$K"
depmod -a "$K"
echo "---"; dkms status "$NAME"; modinfo -n aic8800D80_fdrv; modinfo -n aic_btusb
echo "Instalado. Nada foi carregado. Proximo: sudo ./3_test_load_pcie.sh (com kdump ativo)."
