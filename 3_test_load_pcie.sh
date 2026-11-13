#!/usr/bin/env bash
# Passo 3 (sudo): carrega o driver PCIe UMA vez, com log continuo do kernel em logs/.
# Se o sistema travar/panicar: kdump grava em /var/crash; no reboot o modulo NAO volta (blacklist).
set -uo pipefail
HERE=$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)
P="$HERE"; mkdir -p "$P/logs"; L="$P/logs/load_$(date +%F_%H%M%S).log"
if ! systemctl is-active -q kdump; then
  echo "kdump NAO esta ativo. Rode 1_setup_kdump.sh + reboot antes. (FORCE=1 para ignorar)"; [ "${FORCE:-0}" = 1 ] || exit 1
fi
# Durante o teste: qualquer travamento (soft/hard lockup, hung task) vira panic, o kdump grava
# o dump e REINICIA sozinho em 30s, em vez de deixar o PC congelado. Volta ao normal no reboot.
sysctl -q kernel.panic=30 kernel.softlockup_panic=1 kernel.hardlockup_panic=1 kernel.hung_task_panic=1
sync
journalctl -k -f -o short-precise > "$L" 2>&1 & JP=$!
echo "=== $(date) carregando aic8800D80_fdrv" | tee -a "$L"
modprobe cfg80211; modprobe aic8800D80_fdrv; RC=$?
echo "modprobe rc=$RC"; sleep 10
echo "=== dmesg (ultimos 60)"; journalctl -k --no-pager -o short-precise --since '-2min' | tail -60
echo "=== interfaces"; ip -br link; iw dev 2>/dev/null; rfkill list
echo "=== usb AIC (BT companheira: esperado trocar de 8d84 para 8d85 apos o fw de BT)"; lsusb | grep -i a69c || true
echo "=== NM"; nmcli -t device 2>/dev/null | head
kill $JP 2>/dev/null; chown "${SUDO_USER:-root}": "$L"; echo "log: $L"
