#!/bin/bash

CONFIG="/home/biqu/printer_data/config/save_variables.cfg"
PLR_DIR="/home/biqu/printer_data/gcodes/plr"

Z_HEIGHT="${1:-}"

# =========================================================
# Eingabe prüfen
# =========================================================

if [ -z "$Z_HEIGHT" ]; then
    echo "PLR ERROR: Keine Z-Höhe übergeben."
    exit 1
fi


# =========================================================
# Druckinformationen lesen
# =========================================================

filepath=$(sed -n \
    "s/.*filepath *= *'\([^']*\)'.*/\1/p" \
    "$CONFIG")

last_file=$(sed -n \
    "s/.*last_file *= *'\([^']*\)'.*/\1/p" \
    "$CONFIG")

if [ -z "$filepath" ] || [ -z "$last_file" ]; then
    echo "PLR ERROR: filepath oder last_file fehlt."
    exit 1
fi

if [ ! -f "$filepath" ]; then
    echo "PLR ERROR: Originaldatei nicht gefunden:"
    echo "$filepath"
    exit 1
fi


# =========================================================
# Recovery-Verzeichnis
# =========================================================

mkdir -p "$PLR_DIR"

PLR_FILE="${PLR_DIR}/${last_file}"

echo "PLR Original: $filepath"
echo "PLR Recovery: $PLR_FILE"
echo "PLR Layer Z:  $Z_HEIGHT"


# =========================================================
# Recovery-Layer prüfen
# =========================================================

if ! grep -q "^;Z:${Z_HEIGHT}$" "$filepath"; then
    echo "PLR ERROR: Layer ;Z:${Z_HEIGHT} nicht gefunden."
    exit 1
fi


# =========================================================
# G-Code bis zum Recovery-Layer
# =========================================================

BEFORE_LAYER=$(sed "/^;Z:${Z_HEIGHT}$/q" "$filepath")


# =========================================================
# Temperaturen bestimmen
# =========================================================

BED_TEMP=$(printf '%s\n' "$BEFORE_LAYER" |
    grep -E '^[[:space:]]*M(140|190)[[:space:]]+S[0-9.]+' |
    tail -1 |
    sed -E 's/.*S([0-9.]+).*/\1/')

HOTEND_TEMP=$(printf '%s\n' "$BEFORE_LAYER" |
    grep -E '^[[:space:]]*M(104|109)[[:space:]]+S[0-9.]+' |
    tail -1 |
    sed -E 's/.*S([0-9.]+).*/\1/')


# =========================================================
# Recovery-Datei beginnen
#
# Z = bekannte Layerhöhe
# Z = homed
# X/Y = ausdrücklich unhomed
# =========================================================

cat > "$PLR_FILE" <<EOF
SET_KINEMATIC_POSITION Z=${Z_HEIGHT} SET_HOMED=Z CLEAR_HOMED=XY

M118 PLR: Recovery bei Layer Z=${Z_HEIGHT}

EOF


# =========================================================
# Temperaturen wiederherstellen
# =========================================================

if [ -n "$BED_TEMP" ]; then
    echo "M140 S${BED_TEMP}" >> "$PLR_FILE"
fi

if [ -n "$HOTEND_TEMP" ]; then
    echo "M104 S${HOTEND_TEMP}" >> "$PLR_FILE"
fi

if [ -n "$BED_TEMP" ]; then
    echo "M190 S${BED_TEMP}" >> "$PLR_FILE"
fi

if [ -n "$HOTEND_TEMP" ]; then
    echo "M109 S${HOTEND_TEMP}" >> "$PLR_FILE"
fi


# =========================================================
# Extrusionsmodus wiederherstellen
# =========================================================

if printf '%s\n' "$BEFORE_LAYER" | grep -q '^M83'; then

    echo "G92 E0" >> "$PLR_FILE"
    echo "M83" >> "$PLR_FILE"

else

    LAST_E=$(printf '%s\n' "$BEFORE_LAYER" |
        grep -E '^[[:space:]]*G[01].*[[:space:]]E-?[0-9.]+' |
        tail -1 |
        sed -E 's/.*[[:space:]]E(-?[0-9.]+).*/\1/')

    if [ -n "$LAST_E" ]; then
        echo "G92 E${LAST_E}" >> "$PLR_FILE"
    fi

fi


# =========================================================
# X/Y neu homen
# =========================================================

cat >> "$PLR_FILE" <<EOF

M118 PLR: Home X/Y

G28 X Y

M118 PLR: X/Y Homing abgeschlossen


# =========================================================
# Gespeichertes Bed Mesh wiederherstellen
# =========================================================

M118 PLR: Lade gespeichertes Bed Mesh

BED_MESH_PROFILE LOAD=plr

M118 PLR: Bed Mesh geladen


# =========================================================
# Zur gespeicherten Druckhöhe zurück
# =========================================================

M118 PLR: Fahre auf Z=${Z_HEIGHT}

G90
G1 Z${Z_HEIGHT} F300

M118 PLR: Recovery-Position erreicht

EOF


# =========================================================
# Original-GCode ab Recovery-Layer übernehmen
# =========================================================

awk -v target="$Z_HEIGHT" '

BEGIN {
    found = 0
    current_z = ""
    previous = ""
}

{
    # -----------------------------------------------------
    # Recovery-Layer suchen
    # -----------------------------------------------------

    if (!found) {

        if (previous == ";LAYER_CHANGE" && $0 == ";Z:" target) {

            print previous
            print $0

            current_z = target
            found = 1
            previous = ""

            next
        }

        previous = $0
        next
    }


    # -----------------------------------------------------
    # Aktuelle Layerhöhe merken
    # -----------------------------------------------------

    if ($0 ~ /^;Z:[0-9.]+$/) {

        current_z = $0
        sub(/^;Z:/, "", current_z)

        print
        next
    }


    # -----------------------------------------------------
    # Alte parameterlose LOG_Z reparieren
    # -----------------------------------------------------

    if ($0 ~ /^[[:space:]]*LOG_Z[[:space:]]*$/) {

        if (current_z == "") {

            print "M118 PLR ERROR: LOG_Z ohne bekannte Layerhoehe"

        } else {

            print "LOG_Z Z=" current_z

        }

        next
    }


    # -----------------------------------------------------
    # Rest unverändert übernehmen
    # -----------------------------------------------------

    print
}

' "$filepath" >> "$PLR_FILE"


# =========================================================
# Sicherheitsprüfung LOG_Z
# =========================================================

BAD_LOG_Z=$(grep -cE \
    '^[[:space:]]*LOG_Z[[:space:]]*$' \
    "$PLR_FILE")

if [ "$BAD_LOG_Z" -ne 0 ]; then

    echo
    echo "PLR ERROR:"
    echo "$BAD_LOG_Z parameterlose LOG_Z gefunden."
    echo "Recovery-Datei wird gelöscht."

    rm -f "$PLR_FILE"

    exit 1
fi


# =========================================================
# Recovery-Datei prüfen
# =========================================================

if [ ! -s "$PLR_FILE" ]; then

    echo "PLR ERROR: Recovery-Datei ist leer."

    rm -f "$PLR_FILE"

    exit 1
fi


# =========================================================
# Fertig
# =========================================================

echo
echo "PLR Recovery-Datei erfolgreich erstellt."
echo "Layer: Z=${Z_HEIGHT}"
echo "Datei: ${PLR_FILE}"
echo "Parameterlose LOG_Z: 0"
echo "Bed Mesh: plr"

exit 0
