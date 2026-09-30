#!/bin/bash

set -e

# =========================================================
# KlipperPLR Installer
# =========================================================

echo
echo "=========================================="
echo " KlipperPLR Installer"
echo "=========================================="
echo


# =========================================================
# Benutzer bestimmen
# =========================================================

if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
    PLR_USER="$SUDO_USER"
else
    PLR_USER="$USER"
fi

USER_HOME=$(getent passwd "$PLR_USER" | cut -d: -f6)

if [ -z "$USER_HOME" ]; then
    echo "ERROR: Benutzerverzeichnis konnte nicht bestimmt werden."
    exit 1
fi

echo "User:       $PLR_USER"
echo "Home:       $USER_HOME"


# =========================================================
# Verzeichnisse
# =========================================================

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_DIR="$USER_HOME/klipper"
PRINTER_DATA="$USER_HOME/printer_data"
CONFIG_DIR="$PRINTER_DATA/config"

echo "Repository: $PROJECT_DIR"
echo "Klipper:    $KLIPPER_DIR"
echo "Config:     $CONFIG_DIR"
echo


# =========================================================
# Installation prüfen
# =========================================================

if [ ! -d "$KLIPPER_DIR/klippy/extras" ]; then
    echo "ERROR: Klipper wurde nicht gefunden:"
    echo "$KLIPPER_DIR"
    exit 1
fi

if [ ! -d "$CONFIG_DIR" ]; then
    echo "ERROR: printer_data/config wurde nicht gefunden:"
    echo "$CONFIG_DIR"
    exit 1
fi


# =========================================================
# Shell-Skripte ausführbar machen
# =========================================================

chmod +x "$PROJECT_DIR/plr.sh"
chmod +x "$PROJECT_DIR/clear_plr.sh"
chmod +x "$PROJECT_DIR/install.sh"
chmod +x "$PROJECT_DIR/uninstall.sh"


# =========================================================
# gcode_shell_command installieren
# =========================================================

SHELL_COMMAND_SOURCE="$PROJECT_DIR/gcode_shell_command.py"
SHELL_COMMAND_TARGET="$KLIPPER_DIR/klippy/extras/gcode_shell_command.py"

if [ ! -f "$SHELL_COMMAND_SOURCE" ]; then
    echo "ERROR: gcode_shell_command.py fehlt."
    exit 1
fi

if [ -L "$SHELL_COMMAND_TARGET" ]; then
    rm "$SHELL_COMMAND_TARGET"
elif [ -f "$SHELL_COMMAND_TARGET" ]; then
    BACKUP="${SHELL_COMMAND_TARGET}.backup"
    echo "Bestehende gcode_shell_command.py wird gesichert:"
    echo "$BACKUP"
    cp "$SHELL_COMMAND_TARGET" "$BACKUP"
    rm "$SHELL_COMMAND_TARGET"
fi

ln -s "$SHELL_COMMAND_SOURCE" "$SHELL_COMMAND_TARGET"

echo "gcode_shell_command.py installiert."


# =========================================================
# plr.cfg erzeugen
# =========================================================

PLR_CFG="$CONFIG_DIR/plr.cfg"

cat > "$PLR_CFG" <<EOF_CFG
[respond]
default_type: echo


# =========================================================
# PLR-Dateien löschen
# =========================================================

[gcode_shell_command clear_plr]
command: $PROJECT_DIR/clear_plr.sh
timeout: 5.


[gcode_macro G31]
description: Clear Power Loss Recovery files
gcode:
    RUN_SHELL_COMMAND CMD=clear_plr


# =========================================================
# Aktuelle Druckdatei speichern
# =========================================================

[gcode_macro save_last_file]
description: Save current file for Power Loss Recovery
gcode:
    {% set filepath = printer.virtual_sdcard.file_path %}
    {% set filename = filepath.split('/') %}

    SAVE_VARIABLE VARIABLE=last_file VALUE='"{filename[-1]}"'
    SAVE_VARIABLE VARIABLE=filepath VALUE='"{printer.virtual_sdcard.file_path}"'

    M118 PLR: Datei gespeichert: {filename[-1]}


# =========================================================
# Gespeicherte Druckdatei löschen
# =========================================================

[gcode_macro clear_last_file]
description: Clear saved PLR print information
gcode:
    SAVE_VARIABLE VARIABLE=last_file VALUE='""'
    SAVE_VARIABLE VARIABLE=filepath VALUE='""'
    SAVE_VARIABLE VARIABLE=power_resume_z VALUE=0.0

    M118 PLR: Druck erfolgreich beendet


# =========================================================
# PLR-Shellscript
# =========================================================

[gcode_shell_command POWER_LOSS_RESUME]
command: $PROJECT_DIR/plr.sh
timeout: 420.


# =========================================================
# Unterbrochenen Druck fortsetzen
# =========================================================

[gcode_macro RESUME_INTERRUPTED]
description: Resume print after power loss
gcode:
    SET_GCODE_OFFSET Z=0 MOVE=0

    {% set z_height = params.Z_HEIGHT
        |default(printer.save_variables.variables.power_resume_z)
        |float %}

    {% set last_file = params.GCODE_FILE
        |default(printer.save_variables.variables.last_file)
        |string %}

    {% if z_height <= 0 %}
        {action_raise_error("PLR: Keine gueltige Z-Hoehe gespeichert")}
    {% endif %}

    {% if last_file|length == 0 %}
        {action_raise_error("PLR: Keine Druckdatei gespeichert")}
    {% endif %}

    M118 PLR: Recovery {last_file} bei Z={z_height}

    RUN_SHELL_COMMAND CMD=POWER_LOSS_RESUME PARAMS="{z_height} \"{last_file}\""

    SDCARD_PRINT_FILE FILENAME=plr/"{last_file}"


# =========================================================
# Layerhöhe für PLR speichern
#
# Orca:
#
# LOG_Z Z={layer_z}
# =========================================================

[gcode_macro LOG_Z]
description: Save layer Z supplied by slicer for Power Loss Recovery
gcode:

    {% if params.Z is not defined %}
        {action_raise_error("LOG_Z: Parameter Z fehlt")}
    {% endif %}

    {% set z_pos = params.Z|float %}
    {% set z_pos = (z_pos * 1000)|round / 1000 %}

    {% if printer.print_stats.state == "printing" %}

        SAVE_VARIABLE VARIABLE=power_resume_z VALUE={z_pos}

        RESPOND TYPE=echo MSG="PLR: Layer Z={z_pos} gespeichert"

    {% endif %}
EOF_CFG

echo "plr.cfg installiert:"
echo "$PLR_CFG"


# =========================================================
# printer.cfg
# =========================================================

PRINTER_CFG="$CONFIG_DIR/printer.cfg"

if [ ! -f "$PRINTER_CFG" ]; then
    echo "ERROR: printer.cfg wurde nicht gefunden."
    exit 1
fi

if ! grep -Fxq "[include plr.cfg]" "$PRINTER_CFG"; then
    TEMP_FILE=$(mktemp)

    echo "[include plr.cfg]" > "$TEMP_FILE"
    echo >> "$TEMP_FILE"
    cat "$PRINTER_CFG" >> "$TEMP_FILE"

    mv "$TEMP_FILE" "$PRINTER_CFG"

    echo "[include plr.cfg] zu printer.cfg hinzugefügt."
else
    echo "plr.cfg ist bereits in printer.cfg eingebunden."
fi


# =========================================================
# Moonraker Update Manager
# =========================================================

MOONRAKER_CFG="$CONFIG_DIR/moonraker.conf"
UPDATE_CFG="$CONFIG_DIR/update_plr.cfg"

if [ -f "$MOONRAKER_CFG" ]; then

    if ! grep -Fxq "[include update_plr.cfg]" "$MOONRAKER_CFG"; then
        TEMP_FILE=$(mktemp)

        echo "[include update_plr.cfg]" > "$TEMP_FILE"
        echo >> "$TEMP_FILE"
        cat "$MOONRAKER_CFG" >> "$TEMP_FILE"

        mv "$TEMP_FILE" "$MOONRAKER_CFG"

        echo "[include update_plr.cfg] zu moonraker.conf hinzugefügt."
    fi

    cat > "$UPDATE_CFG" <<EOF_UPDATE
[update_manager KlipperPLR]
type: git_repo
path: $PROJECT_DIR
origin: https://github.com/HerrHaseGermany/KlipperPLR.git
primary_branch: main
install_script: install.sh
is_system_service: False
EOF_UPDATE

    echo "Moonraker Update Manager eingerichtet."

else
    echo "WARNUNG: moonraker.conf wurde nicht gefunden."
    echo "Update Manager wurde nicht eingerichtet."
fi


# =========================================================
# Besitzer korrigieren
# =========================================================

if [ "$(id -u)" -eq 0 ]; then
    chown -R "$PLR_USER:$PLR_USER" "$PROJECT_DIR"
    chown "$PLR_USER:$PLR_USER" "$PLR_CFG"

    if [ -f "$UPDATE_CFG" ]; then
        chown "$PLR_USER:$PLR_USER" "$UPDATE_CFG"
    fi
fi


# =========================================================
# Fertig
# =========================================================

echo
echo "=========================================="
echo " KlipperPLR Installation abgeschlossen"
echo "=========================================="
echo
echo "Repository:"
echo "  $PROJECT_DIR"
echo
echo "Klipper-Konfiguration:"
echo "  $PLR_CFG"
echo
echo "WICHTIG:"
echo "Klipper und Moonraker neu starten."
echo
