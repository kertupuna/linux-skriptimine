#!/bin/bash
# Testandmete loomine varundusharjutuste jaoks
#
# Kasutamine:  bash testandmed.sh
# Loob kausta ~/praks2/src koos alamkaustadega docs, imgs ja bin,
# mida harjutustes 1-12 ja skriptis backupexec.sh varundatakse.

BAAS="$HOME/praks2"

mkdir -p "$BAAS/src/docs" "$BAAS/src/imgs" "$BAAS/src/bin" "$BAAS/backup" "$BAAS/logs"

echo "Esimene dokument" > "$BAAS/src/docs/a.txt"
echo "Teine dokument"   > "$BAAS/src/docs/b.txt"
head -c 20000 /dev/urandom > "$BAAS/src/imgs/b.jpg"     # "pilt"
head -c 10000 /dev/urandom > "$BAAS/src/imgs/c.png"
printf '#!/bin/bash\necho tere\n' > "$BAAS/src/bin/run.sh"
chmod +x "$BAAS/src/bin/run.sh"

# Näidis .backupignore fail (ülesanne 11)
printf 'imgs\n*.tmp\n' > "$BAAS/src/.backupignore"

echo "Testandmed loodud:"
find "$BAAS/src" | sort
