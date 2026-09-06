#!/bin/bash

LICENSE_HELPER=/opt/Autodesk/AdskLicensing/Current/helper/AdskLicensingInstHelper

echo "[*] Registering Maya"

sudo "$LICENSE_HELPER" register \
    -pk 657S1 \
    -pv 2027.0.0.F \
    -el EN_US \
    -cf /opt/maya-install/MayaConfig.pit

"$LICENSE_HELPER" list | grep -q '"sel_prod_key"'
retval=$?

if [[ $retval -ne 0 ]]; then
    echo "[!] Maya registration failed" >&2
fi

exit $retval
