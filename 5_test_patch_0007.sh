#!/bin/bash
# Valida o patch 0007 (tasklet reagendado depois do deinit -> oops no rmmod/suspend).
# Roda como root, de preferencia via systemd-run (a rede cai durante o teste).
# Uso: sudo install -m755 este.sh /usr/local/sbin/ && sudo restorecon /usr/local/sbin/5_test_patch_0007.sh && sudo systemd-run --unit=aic-test-0007 --collect /usr/local/sbin/5_test_patch_0007.sh
LOG=/var/log/aic-test-0007-$(date +%Y%m%d-%H%M%S).log
MOD=aic8800D80_fdrv
CICLOS=${CICLOS:-8}
GW=$(ip route show default | awk '{print $3; exit}')
exec >>"$LOG" 2>&1
log() { echo "[$(date +%T)] $*"; sync; }

wait_conn() {
    for _ in $(seq 1 30); do
        nmcli -t -f DEVICE,STATE device | grep -q '^wlp3s0:connected' && return 0
        sleep 1
    done
    return 1
}

log "INICIO; carregado=$(cat /sys/module/$MOD/srcversion 2>/dev/null) instalado=$(modinfo -F srcversion $MOD)"

if [ "$(cat /sys/module/$MOD/srcversion 2>/dev/null)" != "$(modinfo -F srcversion $MOD)" ]; then
    log "trocando modulo antigo pelo corrigido"
    modprobe -r $MOD; sleep 2; modprobe $MOD
fi
log "carregado agora=$(cat /sys/module/$MOD/srcversion)"
wait_conn && log "wifi conectado" || log "AVISO: wifi nao conectou em 30s"

for i in $(seq 1 "$CICLOS"); do
    ping -q -i 0.05 -w 30 "$GW" >/dev/null 2>&1 &
    sleep 3
    log "ciclo $i: rmmod com trafego"
    modprobe -r $MOD || log "ciclo $i: rmmod FALHOU"
    kill %1 2>/dev/null; wait 2>/dev/null
    sleep 1
    modprobe $MOD || log "ciclo $i: modprobe FALHOU"
    # mesmo passo do sleep hook: sem isto o wpa_supplicant nao volta a escanear
    for _ in $(seq 1 30); do [ -e /sys/class/net/wlp3s0 ] && break; sleep 0.5; done
    systemctl restart wpa_supplicant.service
    wait_conn && log "ciclo $i: ok, reconectou" || log "ciclo $i: AVISO sem conexao"
done

log "suspensao real: rtcwake em 120s + systemctl suspend (hook do system-sleep descarrega o driver)"
rtcwake -m no -s 120
systemctl suspend
sleep 20
log "voltou da suspensao"
wait_conn && log "wifi conectado apos resume" || log "AVISO: wifi sem conexao apos resume"
journalctl -k --since "-15min" --no-pager | grep -E "BUG:|Oops|RIP:|PM: suspend" | tail -10
log "FIM OK"
