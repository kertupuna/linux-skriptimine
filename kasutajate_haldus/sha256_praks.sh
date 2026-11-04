#!/bin/bash
# SHA-256 kontrollsumma mini-praktikum
#
# Kasutamine:  bash sha256_praks.sh
# Näitab, kuidas kontrollsumma arvutada, kontrollida ja et 1 muudetud bait
# muudab kontrollsumma täielikult.

cd "$(mktemp -d)" || exit 1      # töötame ajutises kaustas
echo "Töökaust: $(pwd)"

# 1) Loome faili ja arvutame summa
echo "hello" > demo.txt
sha256sum demo.txt > demo.txt.sha256
echo "--- Kontrollsumma fail:"
cat demo.txt.sha256

# 2) Kontrollime - peab tulema OK
echo "--- Kontroll muutmata failiga:"
sha256sum -c demo.txt.sha256

# 3) "Rikume" faili ja kontrollime uuesti - peab tulema FAILED
echo "x" >> demo.txt
echo "--- Kontroll muudetud failiga:"
sha256sum -c demo.txt.sha256
echo "--- Uus kontrollsumma (täiesti erinev):"
sha256sum demo.txt

# 4) Mitme faili korraga kontroll
echo "a" > fail1.txt
echo "b" > fail2.txt
find . -maxdepth 1 -type f -name 'fail*.txt' -print0 | xargs -0 sha256sum > checksums.txt
echo "--- Mitme faili kontroll:"
sha256sum -c checksums.txt
