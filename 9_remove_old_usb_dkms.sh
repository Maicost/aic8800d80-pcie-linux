#!/usr/bin/env bash
# Opcional (sudo): tira do DKMS o driver USB antigo (aic8800/6.4.3.0), que falha no 7.2
# (strncpy removido) a cada kernel novo. Nao apaga /usr/src/aic8800-6.4.3.0 (fica de backup).
set -euo pipefail
dkms remove -m aic8800 -v 6.4.3.0 --all || true
dkms status
