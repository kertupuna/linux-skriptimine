#!/bin/sh
# Teenuste paigaldus - apache2
#
# Kasutamine (root õigustes):  sh apache_paigaldus.sh
#
# Skript kontrollib, kas veebiserver apache2 on paigaldatud.
#  - kui ei ole, siis paigaldab selle ja käivitab teenuse;
#  - kui on, siis annab sellest teada.
# Mõlemal juhul näidatakse lõpus teenuse staatust.

TEENUS="apache2"

# Paigaldamiseks on vaja root õigusi
if [ "$(id -u)" -ne 0 ]; then
    echo "Skript tuleb käivitada root õigustes (sudo sh $0)"
    exit 1
fi

# dpkg-query -W -f='${Status}' väljastab paketi oleku, nt "install ok installed".
# grep -c loeb, mitu rida sisaldab "ok installed": 1 = paigaldatud, 0 = ei ole.
# 2>/dev/null peidab veateate, kui paketti pole kunagi olnud.
PAIGALDATUD=$(dpkg-query -W -f='${Status}' "$TEENUS" 2>/dev/null | grep -c "ok installed")

if [ "$PAIGALDATUD" -eq 0 ]; then
    echo "$TEENUS ei ole paigaldatud, paigaldan..."

    # Uuendame pakettide nimekirja ja paigaldame teenuse ilma küsimusteta (-y)
    apt-get update
    apt-get install -y "$TEENUS"

    # Kontrollime, kas paigaldamine õnnestus
    if dpkg-query -W -f='${Status}' "$TEENUS" 2>/dev/null | grep -q "ok installed"; then
        echo "$TEENUS on edukalt paigaldatud"
        # Käivitame teenuse ja lubame selle automaatse käivitumise
        systemctl enable --now "$TEENUS"
    else
        echo "VIGA: $TEENUS paigaldamine ebaõnnestus"
        exit 2
    fi
else
    echo "$TEENUS on juba paigaldatud"
fi

# Näitame teenuse staatust (--no-pager: väljund kohe ekraanile, ilma less-ita)
echo
echo "Teenuse $TEENUS staatus:"
systemctl status "$TEENUS" --no-pager | head -n 5
