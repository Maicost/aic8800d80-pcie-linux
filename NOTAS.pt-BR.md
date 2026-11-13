# AIC8800D80 via PCIe (a69c:8d80) no Fedora 44 / kernel 7.2.10

Mudanca de estrategia (2026-10-15): o port anterior usava o chip pela **USB** (a69c:8d84),
que re-enumera sozinha por quirk de firmware. A placa e, na verdade, uma "CM958-like":
**WiFi pela PCIe** (`03:00.0`, a69c:8d80) + **BT pela USB companheira** (8d84 -> 8d85 apos fw).

Fonte: `UGREEN-CM958-75615_Linux_Drive_V1.0.zip` (driver 6.4.3.0 PCIe, 2025-07-29) + os 6
patches do AUR `aic8800d80-pcie-dkms` (compat 6.13+, modalias PCI, logging, bluez, 7.1, 7.2),
`CONFIG_COUNTRY_CODE="BR"` no Makefile do fdrv. Compila limpo no 7.2.10 (gcc 16): ver `logs/`.

## Ordem (cada passo com sudo)
1. `1_setup_kdump.sh` -> **reboot** -> `sudo kdumpctl status` deve dizer operational.
   Motivo: em 2026-10-15 10:46 houve kernel panic (nao capturado) 4s apos ler o config
   space do 03:00.0 com `lspci -vv`. Sem kdump nao da pra saber o que foi.
2. `2_install_pcie.sh` -> firmware + DKMS. Nao carrega e **bloqueia autoload** (blacklist +
   dracut omit) para nao criar boot loop se o driver panicar.
3. `3_test_load_pcie.sh` -> carrega uma vez, com log em `logs/`. Se cair: `/var/crash/`.
4. Se estavel por alguns reboots carregando a mao: apagar `/etc/modprobe.d/aic8800-pcie-test.conf`
   e `/etc/dracut.conf.d/aic8800-pcie.conf` (autoload pelo alias PCI), copiar `aur/aic8800d80-btusb.conf`
   p/ `/etc/modprobe.d/` (softdep btusb -> aic_btusb) e `aur/aic8800d80-sleep-hook` p/
   `/usr/lib/systemd/system-sleep/aic8800d80` (descarrega no suspend).

## Recuperacao
- Se algo autoload-ar e o boot panicar: no GRUB tecle `e` e acrescente
  `modprobe.blacklist=aic8800D80_fdrv,aic_btusb` na linha `linux`.
- NM: `/etc/NetworkManager/conf.d/99-aic-unmanaged.conf` so casa `driver:aic8800_fdrv` (USB);
  o PCIe (`aic8800D80_fdrv`) sera gerenciado normalmente. `30-aic-no-mac-rand.conf` continua valendo.

## Resultado 2026-10-15
- 1a carga: probe falhou ("pci set&tst fail", AER UnsupReq em BAR0+0xc0). Causa: a placa se
  reseta sozinha (watchdog do bootrom, USB re-enumera a cada 24m46s) e o reset ZERA o BAR0;
  `setpci -s 03:00.0 0x10.l` lia 0. iATU (cfg 0x900..) estava programada certinha.
- Fix: `setpci -s 03:00.0 0x10.l=fc700000` + modprobe -> tudo OK; agora o driver faz isso sozinho
  (patch em `aicwf_pcie_init`, src/drivers/aic8800/aic8800_fdrv/aicwf_pcie.c).
- WiFi: `wlp3s0`, perfil Maico 5GHz ch36, -53dBm, VHT-MCS9 80MHz. BT: USB vira a69c:8d85 e o
  `btusb` generico cria hci1 funcionando (aic_btusb nao foi necessario).
- Ainda em blacklist (carregar a mao). Para autoload: apagar os dois arquivos citados acima.
- Reset periodico (24m46s) PARA com firmware rodando (observado 12:45-13:00). Autoload liberado
  (4_enable_autoload.sh); boot com autoload ainda nao testado.
- "Perda" de ping via wlp3s0 era ARP flux (cabo + WiFi na mesma sub-rede):
  /etc/sysctl.d/90-arp-flux-dual-nic.conf (arp_ignore=1, arp_announce=2).
- Vazao LAN (hero -> PC, HTTP 300MB): wlp3s0 278 Mbit/s (5GHz VHT80 MCS8/9 1x1); enp4s0 90 Mbit/s.

## 2026-11-13: kernel 7.3 (patch 0008)
- Sintoma: sem WiFi e sem BT da placa apos o Fedora subir para 7.3.3. O DKMS nao compilou
  (`rwnx_main.c`), entao o firmware nao e carregado e a USB fica em 8d84 (bootrom), sem BT.
- Causa: API do cfg80211 mudou no 7.3: cookie de `remain_on_channel`/`mgmt_tx` passa a vir do
  cfg80211 **por valor** (antes o driver devolvia por ponteiro), `probe_client` virou
  `probe_peer`, `cfg80211_probe_status` ganhou `link_id`.
- Fix: `patches/0008-linux-7.3-compat-feature-detect.patch` (ja aplicado em `src/`). O cookie
  recebido fica guardado (`roc_elem->cookie`, `sw_txhdr->cookie`) e e o que volta nos eventos.
  As tres mudancas sao detectadas **pelo header** no Makefile do fdrv (`AIC_CFG80211_*`), nao por
  `KERNEL_VERSION`. Compila em 7.2.15 e 7.3.3.
- Aplicar: `sudo ./6_update_dkms.sh` (sincroniza `/usr/src`, build, install, carrega).
- Kernel novo quebrou de novo? `grep -nE 'error' /var/lib/dkms/aic8800-pcie/6.4.3.0/build/make.log`.
