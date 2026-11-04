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
ROOT_PAROOL="qwerty"
APT_CONFIG="mysql-apt-config_0.8.40-1_all.deb"

if on_paigaldatud mysql-community-server; then
    echo "MySQL 8.0 on juba paigaldatud."
else
    echo "MySQL 8.0 ei ole paigaldatud, paigaldan..."

    # Vastused mysql-apt-config küsimustele: versioon 8.0, tools välja, Ok
    echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.0" | debconf-set-selections
    echo "mysql-apt-config mysql-apt-config/select-tools select Disabled" | debconf-set-selections
    echo "mysql-apt-config mysql-apt-config/select-product select Ok" | debconf-set-selections

    # Root parool ja autentimise valik
    echo "mysql-community-server mysql-community-server/root-pass password $ROOT_PAROOL" | debconf-set-selections
    echo "mysql-community-server mysql-community-server/re-root-pass password $ROOT_PAROOL" | debconf-set-selections
    echo "mysql-community-server mysql-server/default-auth-override select Use Strong Password Encryption (RECOMMENDED)" | debconf-set-selections

    # Oracle MySQL APT repositoorium
    wget -O /tmp/$APT_CONFIG https://dev.mysql.com/get/$APT_CONFIG
    dpkg -i /tmp/$APT_CONFIG

    # MySQL serveri paigaldus
    apt-get update
    apt-get install -y mysql-server

    # Kontrollime tulemust
    if on_paigaldatud mysql-community-server; then
        echo "MySQL 8.0 paigaldamine õnnestus."
    else
        echo "VIGA: MySQL paigaldamine ebaõnnestus!"
        exit 1
    fi
fi

# Teenus töötab ja käivitub koos süsteemiga
systemctl enable --now mysql

# /root/.my.cnf - mysql klient ei küsi parooli
cat > /root/.my.cnf <<EOF
[client]
host=localhost
user=root
password=$ROOT_PAROOL
EOF
chmod 600 /root/.my.cnf
# 3. Apache2
# Kontroll: kas Apache2 on olemas?
# Kui ei ole:
# - Apache2 paigaldamine
# - teenuse käivitamine
# Apache default page
if on_paigaldatud apache2; then
    echo "Apache2 on juba paigaldatud."
else
    echo "Apache2 ei ole paigaldatud, paigaldan..."
    apt-get install -y apache2

    # Kontrollime tulemust
    if on_paigaldatud apache2; then
        echo "Apache2 paigaldamine õnnestus."
    else
        echo "VIGA: Apache2 paigaldamine ebaõnnestus!"
        exit 1
    fi
fi

# Teenus töötab ja käivitub koos süsteemiga
systemctl enable --now apache2

# Apache vaikimisi veebileht
AEG=$(date "+%Y-%m-%d %H:%M:%S")
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html>
<head><meta charset="UTF-8"><title>LAMP</title></head>
<body>
  <h1>LAMP server töötab!</h1>
  <p>Õpilane: Kertu Puna</p>
  <p>Grupp: ITS24</p>
  <p>Paigaldatud: $AEG</p>
</body>
</html>
EOF
# 4. PHP 8.x
# Kontroll: kas PHP 8.x on olemas?
# Kui ei ole:
# - PHP ja moodulite paigaldamine
# info.php loomine
# Ubuntu 24.04 vaikimisi PHP versioon on 8.3
# (juhendis toodud php8.2 paketid on Debian 12 jaoks)
if on_paigaldatud php8.3; then
    echo "PHP 8.x on juba paigaldatud: $(php -v | head -n 1)"
else
    echo "PHP 8.x ei ole paigaldatud, paigaldan..."
    apt-get install -y php8.3 php8.3-cli php8.3-common php8.3-mysql libapache2-mod-php8.3

    # Kontrollime tulemust
    if on_paigaldatud php8.3; then
        echo "PHP paigaldamine õnnestus: $(php -v | head -n 1)"
    else
        echo "VIGA: PHP paigaldamine ebaõnnestus!"
        exit 1
    fi
fi

# PHP testleht
echo "<?php phpinfo(); ?>" > /var/www/html/info.php

# Apache taaskäivitus, et PHP moodul laaditaks
systemctl restart apache2
# 5. Kontrollid ja raport
