#!/bin/bash
# Kasutajate kodukataloogide varundamine
#
# Kasutamine (root õigustes):  bash varundakodud.sh
#
# Skript arhiveerib ja pakib iga kasutaja kodukataloogi /home kaustast eraldi
# arhiiviks kujul kasutaja.PP.KK.AAAA.tar.gz ning salvestab arhiivid
# kataloogi /home_bcp. Skript töötab sõltumata sellest, millisest kaustast
# see käivitatakse, sest kõik teed on absoluutsed (tar -C /home).

KODUD="/home"                 # kust kodukataloogid võetakse
VARUKAUST="/home_bcp"         # kuhu varukoopiad salvestatakse
KUUPAEV=$(date +%d.%m.%Y)     # varundamise kuupäev, nt 21.10.2026

# Kodukataloogide lugemiseks on vaja root õigusi
if [ "$(id -u)" -ne 0 ]; then
    echo "Skript tuleb käivitada root õigustes (sudo bash $0)"
    exit 1
fi

# Loome varukoopiate kausta, kui seda veel pole (-p ei anna viga, kui on olemas)
mkdir -p "$VARUKAUST"
chmod 700 "$VARUKAUST"        # varukoopiaid tohib lugeda ainult root

# Käime läbi kõik /home all olevad kataloogid
for KATALOOG in "$KODUD"/*/; do
    [ -d "$KATALOOG" ] || continue          # kui /home on tühi, jätame vahele
    KASUTAJA=$(basename "$KATALOOG")        # kataloogi nimi = kasutaja nimi
    ARHIIV="$VARUKAUST/$KASUTAJA.$KUUPAEV.tar.gz"

    # -c loob arhiivi, -z pakib gzip-iga, -f määrab faili nime,
    # -C /home liigub enne pakkimist /home kausta, et arhiivis oleksid
    # suhtelised teed (kasutaja/...), mitte /home/kasutaja/...
    if tar -czf "$ARHIIV" -C "$KODUD" "$KASUTAJA"; then
        echo "OK:    $KASUTAJA -> $ARHIIV ($(du -h "$ARHIIV" | cut -f1))"
    else
        echo "VIGA:  $KASUTAJA kodukataloogi varundamine ebaõnnestus"
    fi
done

echo
echo "Varukoopiad kaustas $VARUKAUST:"
ls -lh "$VARUKAUST"
