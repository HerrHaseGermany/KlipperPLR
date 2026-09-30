#!/bin/bash

set -e

USER_HOME="$(getent passwd "$(id -un)" | cut -d: -f6)"

if [ -z "$USER_HOME" ]; then
    echo "PLR ERROR: Benutzerverzeichnis konnte nicht bestimmt werden."
    exit 1
fi

PLR_DIR="$USER_HOME/printer_data/gcodes/plr"

rm -rf "$PLR_DIR"
