#!/bin/sh
# Teenuste paigaldus - php
#
# Kasutamine (root õigustes):  sh php_paigaldus.sh
#
# Skript kontrollib, kas PHP ja veebiserveri tööks vajalikud abipaketid on
# paigaldatud. Puuduvad paketid paigaldatakse, seadistatakse Apache eelistama
# index.php faili ja tehakse Apache taaskäivitus. Tulemus väljastatakse
# analoogselt apache_paigaldus.sh skriptiga.
#
# Ubuntu 24.04 versioonipõhiste nimede (php8.3 jne) asemel kasutame
# üldnimesid, mis paigaldavad alati distributsiooni vaikimisi PHP versiooni:
#   php                - PHP ise
#   libapache2-mod-php - Apache moodul PHP lehtede käivitamiseks
#   php-mysql          - MySQL tugi (vaja hiljem MySQL kasutamiseks)

PAKETID="php libapache2-mod-php php-mysql"
DIR_CONF="/etc/apache2/mods-enabled/dir.conf"
TESTLEHT="/var/www/html/info.php"

# Paigaldamiseks on vaja root õigusi
if [ "$(id -u)" -ne 0 ]; then
    echo "Skript tuleb käivitada root õigustes (sudo sh $0)"
    exit 1
fi

# Funktsioon: kas pakett on paigaldatud? (0 = jah, 1 = ei)
on_paigaldatud() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"
}

# Kogume kokku puuduvad paketid
PUUDU=""
for P in $PAKETID; do
    if on_paigaldatud "$P"; then
        echo "$P on juba paigaldatud"
    else
        echo "$P ei ole paigaldatud"
        PUUDU="$PUUDU $P"
    fi
done

if [ -n "$PUUDU" ]; then
    echo "Paigaldan:$PUUDU"
    apt-get update
    apt-get install -y $PUUDU

    # Kontrollime, et kõik paketid said paigaldatud
    for P in $PUUDU; do
        if on_paigaldatud "$P"; then
            echo "$P on edukalt paigaldatud"
        else
            echo "VIGA: $P paigaldamine ebaõnnestus"
            exit 2
        fi
    done
else
    echo "PHP ja kõik abipaketid on juba paigaldatud"
fi

# Konfiguratsioon: Apache otsigu kaustast esmalt index.php, siis index.html
if [ -f "$DIR_CONF" ] && ! grep -q "DirectoryIndex index.php" "$DIR_CONF"; then
    sed -i 's/DirectoryIndex .*/DirectoryIndex index.php index.html index.cgi index.pl index.xhtml index.htm/' "$DIR_CONF"
    echo "Muudetud $DIR_CONF: index.php on esimesel kohal"
fi

# Testleht, millega saab brauseris kontrollida, et PHP töötab
if [ ! -f "$TESTLEHT" ]; then
    echo "<?php phpinfo(); ?>" > "$TESTLEHT"
    echo "Loodud testleht $TESTLEHT"
fi

# Apache peab uue mooduli ja seadistuse laadimiseks taaskäivituma
systemctl restart apache2

# Tulemuse väljastamine
echo
echo "PHP versioon:"
php -v | head -n 1
echo
echo "Apache PHP moodul:"
apache2ctl -M 2>/dev/null | grep -i php || echo "PHP moodulit ei leitud!"
echo
echo "Teenuse apache2 staatus:"
systemctl status apache2 --no-pager | head -n 5
echo
echo "Kontroll brauseris: http://$(hostname -I | awk '{print $1}')/info.php"
