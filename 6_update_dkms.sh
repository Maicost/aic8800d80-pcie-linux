#!/usr/bin/env bash
# (sudo) Sincroniza pcie/src -> /usr/src e reconstroi o DKMS para o kernel em uso.
# Usar depois de mudar o fonte (ex.: patch 0008, API do cfg80211 no kernel 7.3) ou
# quando um kernel novo ficar sem modulo. Kernels antigos ja instalados nao sao tocados.
#   sudo ./6_update_dkms.sh          # build + install + carrega o driver
#   sudo ./6_update_dkms.sh --noload # so build + install
set -euo pipefail
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
SRC="$HERE/src"
NAME=aic8800-pcie; VER=6.4.3.0; K=$(uname -r)
[ "$(id -u)" = 0 ] || { echo "rode com sudo"; exit 1; }
[ -d "/usr/src/kernels/$K" ] || { echo "falta kernel-devel-$K"; exit 1; }

rsync -a --delete "$SRC"/ "/usr/src/$NAME-$VER"/
[ -e "/var/lib/dkms/$NAME/$VER/source" ] || dkms add -m "$NAME" -v "$VER"
# build falho anterior deixa o diretorio build/ para tras
dkms unbuild -m "$NAME" -v "$VER" -k "$K" >/dev/null 2>&1 || true
if ! dkms build -m "$NAME" -v "$VER" -k "$K"; then
	echo "BUILD FALHOU. Erros:"
	grep -nE 'error|\*\*\*' "/var/lib/dkms/$NAME/$VER/build/make.log" | head -40
	exit 1
fi
dkms install --force -m "$NAME" -v "$VER" -k "$K"
depmod -a "$K"
echo "---"; dkms status "$NAME"; modinfo -n aic8800D80_fdrv

[ "${1:-}" = "--noload" ] && exit 0
if [ ! -d /sys/module/aic8800D80_fdrv ]; then
	modprobe aic8800D80_fdrv
	sleep 6
	# mesmo motivo do sleep hook: o supplicant pode ficar preso ao netdev antigo
	systemctl restart wpa_supplicant
	sleep 8
fi
echo "---"; nmcli -t dev status | grep -E 'wifi|wlp' || echo "sem interface wifi ainda"
rfkill list
dmesg | grep -iE 'aic|rwnx' | tail -15
