#!/bin/bash
# lamp-install.sh - LAMP keskkonna paigaldus ühe skriptiga
# Apache2 + PHP 8.x + MySQL Server 8.0 (Oracle)
# Käivitamine root õigustes: sudo ./lamp-install.sh

set -e
export DEBIAN_FRONTEND=noninteractive

# 1. Vajalikud abipaketid
# Skript tuleb käivitada root õigustes
if [ "$(id -u)" -ne 0 ]; then
    echo "Skript tuleb käivitada root õigustes (sudo ./lamp-install.sh)"
    exit 1
fi

# Funktsioon: kas pakett on paigaldatud? (0 = jah, 1 = ei)
on_paigaldatud() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"
}

# Uuendame paketiloendit ja paigaldame abipaketid
apt-get update
apt-get install -y wget ca-certificates gnupg debconf-utils
# 2. MySQL 8.0
# Kontroll: kas MySQL 8.0 on olemas?
# Kui ei ole:
# - debconf-set-selections
# - Oracle MySQL APT
# - mysql-server
# - teenuse käivitamine
# /root/.my.cnf loomine

# 3. Apache2
# Kontroll: kas Apache2 on olemas?
# Kui ei ole:
# - Apache2 paigaldamine
# - teenuse käivitamine
# Apache default page

# 4. PHP 8.x
# Kontroll: kas PHP 8.x on olemas?
# Kui ei ole:
# - PHP ja moodulite paigaldamine
# info.php loomine

# 5. Kontrollid ja raport
