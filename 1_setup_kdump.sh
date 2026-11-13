#!/usr/bin/env bash
# Passo 1 (sudo): arma o kdump para que um proximo panic deixe vmcore + dmesg em /var/crash.
# Exige REBOOT depois (o crashkernel= so entra no proximo boot).
set -euo pipefail
kdumpctl reset-crashkernel --kernel=ALL
systemctl enable kdump
echo "crashkernel aplicado ao GRUB. Reinicie e confira:  sudo kdumpctl status   (esperado: 'Kdump is operational')"
grubby --info=DEFAULT | grep -o 'crashkernel=[^ ]*' || true
