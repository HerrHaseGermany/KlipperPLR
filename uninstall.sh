#!/bin/bash

set -e

echo
echo "=========================================="
echo " KlipperPLR Uninstaller"
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


PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KLIPPER_DIR="$USER_HOME/klipper"
CONFIG_DIR="$USER_HOME/printer_data/config"
GCODE_DIR="$USER_HOME/printer_data/gcodes/plr"


# =========================================================
# printer.cfg bereinigen
# =========================================================

PRINTER_CFG="$CONFIG_DIR/printer.cfg"

if [ -f "$PRINTER_CFG" ]; then
    sed -i '/^[[:space:]]*\[include plr\.cfg\][[:space:]]*$/d' "$PRINTER_CFG"
fi


# =========================================================
# Moonraker bereinigen
# =========================================================

MOONRAKER_CFG="$CONFIG_DIR/moonraker.conf"

if [ -f "$MOONRAKER_CFG" ]; then
    sed -i '/^[[:space:]]*\[include update_plr\.cfg\][[:space:]]*$/d' "$MOONRAKER_CFG"
fi


# =========================================================
# Konfigurationsdateien löschen
# =========================================================

rm -f "$CONFIG_DIR/plr.cfg"
rm -f "$CONFIG_DIR/update_plr.cfg"


# =========================================================
# Recovery-GCodes löschen
# =========================================================

rm -rf "$GCODE_DIR"


# =========================================================
# gcode_shell_command Symlink entfernen
# =========================================================

SHELL_COMMAND_TARGET="$KLIPPER_DIR/klippy/extras/gcode_shell_command.py"

if [ -L "$SHELL_COMMAND_TARGET" ]; then

    LINK_TARGET=$(readlink -f "$SHELL_COMMAND_TARGET" || true)

    if [ "$LINK_TARGET" = "$PROJECT_DIR/gcode_shell_command.py" ]; then
        rm "$SHELL_COMMAND_TARGET"
        echo "gcode_shell_command.py Symlink entfernt."
    fi

fi


# =========================================================
# Fertig
# =========================================================

echo
echo "=========================================="
echo " KlipperPLR wurde deinstalliert"
echo "=========================================="
echo
echo "Das Git-Repository wurde NICHT gelöscht:"
echo "  $PROJECT_DIR"
echo
echo "Klipper und Moonraker neu starten."
echo
