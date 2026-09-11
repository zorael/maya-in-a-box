#!/bin/bash
set -euo pipefail

LICENSE_HELPER=/opt/Autodesk/AdskLicensing/Current/helper/AdskLicensingInstHelper

echo "[*] Registering Maya"

sudo "$LICENSE_HELPER" register \
    -pk 657S1 \
    -pv 2027.0.0.F \
    -el EN_US \
    -cf /opt/maya-install/MayaConfig.pit || true

if "$LICENSE_HELPER" list | grep -q '"sel_prod_key"'; then
    echo "[*] Maya registration successful"
    exit 0
else
    echo "[x] Maya registration failed" >&2
    exit 1
fi
