#!/bin/bash
# Teenuste paigaldus - Oracle MySQL Server 8.0
#
# Kasutamine (root õigustes):  bash mysql_paigaldus.sh
#
# Skript kontrollib, kas MySQL server on paigaldatud. Kui ei ole, lisab
# Oracle'i ametliku APT repositooriumi ja paigaldab MySQL 8.0 täiesti
# mitteinteraktiivselt (vastused antakse ette debconf-set-selections abil).
# Lõpuks luuakse root kasutajale fail ~/.my.cnf, et mysql klient saaks
# ühenduda ilma parooli küsimata, ning näidatakse teenuse staatust.

set -e                                  # vea korral lõpetab skript kohe töö

TEENUS="mysql"
ROOT_PAROOL="qwerty"                    # laboris kokku lepitud parool
APT_CONFIG="mysql-apt-config_0.8.40-1_all.deb"
APT_URL="https://dev.mysql.com/get/$APT_CONFIG"

# Paigaldamiseks on vaja root õigusi
if [ "$(id -u)" -ne 0 ]; then
    echo "Skript tuleb käivitada root õigustes (sudo bash $0)"
    exit 1
fi

# Kas pakett on paigaldatud? (0 = jah, 1 = ei)
on_paigaldatud() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"
}

if on_paigaldatud mysql-community-server || on_paigaldatud mysql-server; then
    echo "MySQL server on juba paigaldatud"
else
    echo "MySQL server ei ole paigaldatud, paigaldan..."

    # apt ja dpkg ei näita sinist küsimuste akent, vaid kasutavad ette antud vastuseid
    export DEBIAN_FRONTEND=noninteractive

    # Abitööriistad: gnupg (võtmed), ca-certificates (HTTPS), debconf-utils
    # (debconf-set-selections) ja wget (allalaadimine)
    apt-get update
    apt-get install -y gnupg ca-certificates debconf-utils wget

    # 1) Vastused mysql-apt-config paketi küsimustele:
    #    MySQL versioon 8.0, tööriistad välja, kinnitus "Ok"
    echo "mysql-apt-config mysql-apt-config/select-server select mysql-8.0" | debconf-set-selections
    echo "mysql-apt-config mysql-apt-config/select-tools select Disabled" | debconf-set-selections
    echo "mysql-apt-config mysql-apt-config/select-product select Ok" | debconf-set-selections

    # 2) Root parool, mida MySQL 8.0 paigaldamise ajal küsib
    echo "mysql-community-server mysql-community-server/root-pass password $ROOT_PAROOL" | debconf-set-selections
    echo "mysql-community-server mysql-community-server/re-root-pass password $ROOT_PAROOL" | debconf-set-selections

    # 3) Autentimisplugin: soovitatud caching_sha2_password
    echo "mysql-community-server mysql-server/default-auth-override select Use Strong Password Encryption (RECOMMENDED)" | debconf-set-selections

    # 4) Oracle'i APT konfiguratsioonipakett lisab repositooriumi ja võtmed
    wget -q -O "/tmp/$APT_CONFIG" "$APT_URL"
    dpkg -i "/tmp/$APT_CONFIG"
    rm -f "/tmp/$APT_CONFIG"            # ajutine fail pole enam vajalik

    # 5) Uuendame paketiinfot ja paigaldame MySQL serveri
    apt-get update
    apt-get install -y mysql-server

    # 6) Teenus käivitub kohe ja ka pärast taaskäivitust
    systemctl enable --now "$TEENUS"

    if on_paigaldatud mysql-community-server || on_paigaldatud mysql-server; then
        echo "MySQL server on edukalt paigaldatud"
    else
        echo "VIGA: MySQL serveri paigaldamine ebaõnnestus"
        exit 2
    fi
fi

# 7) Root kasutaja klientkonfiguratsioon ~/.my.cnf (ainult omanik tohib lugeda)
MYCNF="$HOME/.my.cnf"
if [ ! -f "$MYCNF" ]; then
    cat > "$MYCNF" <<EOF
[client]
host=localhost
user=root
password=$ROOT_PAROOL
EOF
    chmod 600 "$MYCNF"
    echo "Loodud $MYCNF"
else
    echo "$MYCNF on juba olemas"
fi

# Tulemuse väljastamine
echo
echo "MySQL versioon:"
mysql --version
echo
echo "Ühenduse kontroll (.my.cnf abil, parooli ei küsita):"
mysql -e "SELECT VERSION() AS versioon, CURRENT_USER() AS kasutaja;" || echo "Ühendus ebaõnnestus!"
echo
echo "Teenuse $TEENUS staatus:"
systemctl status "$TEENUS" --no-pager | head -n 5
