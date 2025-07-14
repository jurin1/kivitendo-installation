#!/bin/bash

# Gemeinsame Bibliothek für Farben, Icons und Hilfsfunktionen

# Farben und Symbole für die Ausgabe
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_RED='\033[0;31m'
export COLOR_BLUE='\033[0;34m'
export COLOR_RESET='\033[0m'

export ICON_OK="✅"
export ICON_WARN="⚠️"
export ICON_ERROR="❌"
export ICON_INFO="ℹ️"
export ICON_ROCKET="🚀"

# Funktion zur formatierten Ausgabe
print_message() {
    local color=$1
    local icon=$2
    local message=$3
    echo -e "${color}${icon} ${message}${COLOR_RESET}"
}