#!/bin/bash
# backupexec.sh - varukoopia kuupäevaga ja kontrolliga (ülesanne 12)
#
# Ühendab harjutuste 1-11 sammud üheks skriptiks:
#   1) varukoopia kuupäeva ja kellaajaga failinimes
#   2) arhiivi kontroll (avaneb ja sisaldab alamkaustu)
#   3) arhiivi suuruse näitamine
#   4) ainult N viimase koopia hoidmine
#   5) failide välistamine (--exclude)
#   6) "kuiv jooks" (-n) - näitab, mis läheks arhiivi, arhiivi ei loo
#   7) logimine faili ~/praks2/logs/backup.log
#   8) vaba ruumi kontroll enne varundamist
#   9) SHA-256 kontrollsumma loomine ja kontroll
#  10) kompressori valik (zstd / xz / gzip)
#  11) .backupignore faili kasutamine
#  + ajutine kaust (mktemp -d) ja selle kustutamine (trap ... EXIT)
#
# Kasutamine:
#   bash backupexec.sh [-n] [-c zstd|xz|gz] [-k arv] [lähtekaust]
#     -n          kuiv jooks, arhiivi ei looda
#     -c          kompressor (vaikimisi parim olemasolev: zstd > xz > gz)
#     -k arv      mitu viimast koopiat alles jätta (vaikimisi 3)
#     lähtekaust  mida varundada (vaikimisi ~/praks2/src)

set -u                                  # kasutamata muutuja on viga

# ---------- Seaded ----------
SRC="$HOME/praks2/src"
BACKUP_DIR="$HOME/praks2/backup"
LOG_DIR="$HOME/praks2/logs"
LOG="$LOG_DIR/backup.log"
KEEP=3
DRY_RUN=0
COMP=""
EXCLUDES=(--exclude='*.tmp' --exclude='*.swp')   # alati välistatavad failid

# ---------- Abifunktsioonid ----------
# log: kirjutab teate ekraanile ja logifaili koos ajatempliga (ülesanne 7)
log() {
    local rida
    rida=$(printf '[ %s ] %s' "$(date '+%F %T')" "$*")
    echo "$rida"
    [ "$DRY_RUN" -eq 1 ] || echo "$rida" >> "$LOG"
}

# viga: logib vea ja lõpetab skripti
viga() {
    log "VIGA: $*"
    log "BACKUP FAILED"
    exit 1
}

# ---------- Parameetrite lugemine ----------
while getopts "nc:k:h" opt; do
    case "$opt" in
        n) DRY_RUN=1 ;;
        c) COMP="$OPTARG" ;;
        k) KEEP="$OPTARG" ;;
        h) sed -n '2,24p' "$0"; exit 0 ;;
        *) echo "Vale parameeter, vaata: $0 -h"; exit 1 ;;
    esac
done
shift $((OPTIND - 1))
[ $# -ge 1 ] && SRC="$1"

SRC=$(realpath -m "$SRC")               # absoluutne tee
SRC_PARENT=$(dirname "$SRC")            # nt /home/kertu/praks2
SRC_NAME=$(basename "$SRC")             # nt src

mkdir -p "$BACKUP_DIR" "$LOG_DIR"

[ "$DRY_RUN" -eq 1 ] && echo "*** KUIV JOOKS - arhiivi ei looda ***"
log "BACKUP START: $SRC"

# Lähtekaust peab olemas olema
[ -d "$SRC" ] || viga "lähtekausta $SRC ei ole olemas"

# ---------- 10) Kompressori valik ----------
# Kui kasutaja ei valinud, võtame parima olemasoleva
if [ -z "$COMP" ]; then
    if command -v zstd >/dev/null 2>&1; then COMP=zstd
    elif command -v xz >/dev/null 2>&1; then COMP=xz
    else COMP=gz
    fi
fi
case "$COMP" in
    zstd) TAR_COMP=(-I 'zstd -19 -T0'); UNPACK=(-I 'zstd -d'); EXT="tar.zst"
          command -v zstd >/dev/null 2>&1 || viga "zstd puudub (sudo apt install zstd)" ;;
    xz)   TAR_COMP=(-J); UNPACK=(-J); EXT="tar.xz" ;;
    gz)   TAR_COMP=(-z); UNPACK=(-z); EXT="tar.gz" ;;
    *)    viga "tundmatu kompressor: $COMP (lubatud: zstd, xz, gz)" ;;
esac
log "Kompressor: $COMP"

# ---------- 5) ja 11) Välistused ----------
IGNORE_FILE="$SRC/.backupignore"
if [ -f "$IGNORE_FILE" ]; then
    EXCLUDES+=(--exclude-from="$IGNORE_FILE")
    log "Kasutan välistusi failist $IGNORE_FILE: $(grep -v '^#' "$IGNORE_FILE" | tr '\n' ' ')"
fi

# ---------- 6) Kuiv jooks ----------
if [ "$DRY_RUN" -eq 1 ]; then
    echo "Arhiivi läheksid järgmised failid:"
    # arhiiv kirjutatakse standardväljundisse (-f -) ja loetakse kohe tagasi
    tar -cf - "${EXCLUDES[@]}" -C "$SRC_PARENT" "$SRC_NAME" | tar -tvf -
    echo "Kokku: $(tar -cf - "${EXCLUDES[@]}" -C "$SRC_PARENT" "$SRC_NAME" | tar -tf - | wc -l) kirjet"
    exit 0
fi

# ---------- 8) Vaba ruumi kontroll ----------
VAJA=$(du -sb "$SRC" | awk '{print $1}')                  # lähtekausta suurus baitides
VABA=$(df -B1 "$BACKUP_DIR" | awk 'NR==2{print $4}')      # vaba ruum baitides
log "Lähteandmed: $VAJA B, vaba ruum: $VABA B"
# Pakkimata suurus on halvim juht - kui see ei mahu, ei alusta
[ "$VAJA" -lt "$VABA" ] || viga "vaba ruumi ei ole piisavalt"

# ---------- 1) Arhiivi nimi ja olemasolu kontroll ----------
AEG=$(date +%F_%H-%M-%S)
ARHIIV_NIMI="${SRC_NAME}_${AEG}.${EXT}"
ARHIIV="$BACKUP_DIR/$ARHIIV_NIMI"
[ -e "$ARHIIV" ] && viga "arhiiv $ARHIIV on juba olemas"

# ---------- Ajutine kaust ja koristamine ----------
TMP=$(mktemp -d)                        # nt /tmp/tmp.XXXXXXXX
trap 'rm -rf "$TMP"' EXIT               # kustutatakse alati skripti lõpus
log "Ajutine kaust: $TMP"

# Arhiiv tehakse esmalt ajutisse kausta, et poolik fail ei satuks varukausta
if ! tar "${TAR_COMP[@]}" -cf "$TMP/$ARHIIV_NIMI" "${EXCLUDES[@]}" -C "$SRC_PARENT" "$SRC_NAME"; then
    viga "arhiivi loomine ebaõnnestus"
fi

# ---------- 2) Arhiivi kontroll ----------
SISU=$(tar "${UNPACK[@]}" -tf "$TMP/$ARHIIV_NIMI") || viga "arhiiv on vigane ja ei avane"
ALAMKAUSTU=$(echo "$SISU" | grep -c "^$SRC_NAME/.*/$")
log "Arhiiv avaneb, kirjeid: $(echo "$SISU" | wc -l), alamkaustu: $ALAMKAUSTU"
echo "$SISU" | head -n 5
[ "$ALAMKAUSTU" -gt 0 ] || log "HOIATUS: arhiivis pole ühtegi alamkausta"

# ---------- 9) SHA-256 kontrollsumma ----------
( cd "$TMP" && sha256sum "$ARHIIV_NIMI" > "$ARHIIV_NIMI.sha256" ) || viga "kontrollsumma arvutamine ebaõnnestus"

# Tõstame arhiivi ja kontrollsumma varukausta
mv "$TMP/$ARHIIV_NIMI" "$TMP/$ARHIIV_NIMI.sha256" "$BACKUP_DIR/" || viga "arhiivi teisaldamine ebaõnnestus"

# Kontrollime, et kopeeritud fail on terve
if ( cd "$BACKUP_DIR" && sha256sum -c "$ARHIIV_NIMI.sha256" >/dev/null ); then
    log "SHA-256 kontroll: OK ($(cut -c1-16 "$ARHIIV.sha256")...)"
else
    viga "SHA-256 kontroll ebaõnnestus"
fi

# ---------- 3) Suurus ----------
log "Arhiiv: $ARHIIV, suurus: $(du -h "$ARHIIV" | awk '{print $1}')"

# ---------- 4) Ainult viimased KEEP koopiat ----------
VANAD=$(ls -1t "$BACKUP_DIR"/"${SRC_NAME}"_*.tar.* 2>/dev/null | grep -v '\.sha256$' | tail -n +$((KEEP + 1)))
for F in $VANAD; do
    rm -f "$F" "$F.sha256"
    log "Kustutatud vana koopia: $(basename "$F")"
done

log "BACKUP OK"
