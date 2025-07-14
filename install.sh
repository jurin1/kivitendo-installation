#!/bin/bash

# Das Skript bei einem Fehler sofort beenden
set -e

# --- Konfiguration ---
SCRIPTS_DIR="$(dirname "$0")/scripts"
CONFIG_FILE="$(dirname "$0")/kivitendo.conf"

# Lade die gemeinsame Bibliothek für Farben und Funktionen
# Stelle sicher, dass diese Zeile in allen Skripten vorhanden ist
source "${SCRIPTS_DIR}/lib/common.sh"

# --- Root-Check ---
if [ "$EUID" -ne 0 ]; then
  print_message "${COLOR_RED}" "${ICON_ERROR}" "Bitte führe das Skript mit sudo oder als root aus: sudo ./install.sh"
  exit 1
fi

# --- Hauptfunktion ---
main() {
    print_message "${COLOR_BLUE}" "${ICON_ROCKET}" "Willkommen zum Kivitendo Installations-Skript!"
    print_message "${COLOR_BLUE}" "${ICON_ROCKET}" "Die Installation wird in 4 Schritten durchgeführt."
    echo

    # Schritt 1: Betriebssystem vorbereiten
    print_message "${COLOR_BLUE}" "--- (1/4) Betriebssystem wird vorbereitet ---"
    bash "${SCRIPTS_DIR}/01_prepare_os.sh"
    echo

    # Schritt 2: PostgreSQL installieren
    print_message "${COLOR_BLUE}" "--- (2/4) PostgreSQL wird installiert und konfiguriert ---"
    bash "${SCRIPTS_DIR}/02_install_postgres.sh"
    echo

    # Schritt 3: Apache2 installieren
    print_message "${COLOR_BLUE}" "--- (3/4) Apache2 Webserver wird installiert und konfiguriert ---"
    # KORREKTUR: Die folgende Zeile war auskommentiert
    bash "${SCRIPTS_DIR}/03_install_apache.sh"
    echo

    # Schritt 4: Kivitendo installieren
    print_message "${COLOR_BLUE}" "--- (4/4) Kivitendo wird installiert und konfiguriert ---"
    # KORREKTUR: Die folgende Zeile war auskommentiert
    bash "${SCRIPTS_DIR}/04_install_kivitendo.sh"
    echo

    print_message "${COLOR_GREEN}" "🎉 🎉 🎉  Installation erfolgreich abgeschlossen! 🎉 🎉 🎉"
    echo

    # Finale Zusammenfassung aus der Konfig-Datei lesen
    if [ -f "$CONFIG_FILE" ]; then
        # Lade die Variablen aus der Konfig-Datei
        source "$CONFIG_FILE"
        print_message "${COLOR_YELLOW}" "${ICON_INFO}" "Hier ist deine Zusammenfassung für das Kivitendo-Setup:"
        echo "------------------------------------------------------------------"
        echo -e "  Web-Adresse:        ${COLOR_GREEN}http://${KIVI_SERVER_NAME}${COLOR_RESET}"
        echo -e "  (Trage '${KIVI_SERVER_NAME}' in deiner lokalen hosts-Datei oder DNS ein)"
        echo -e "  Admin-Webuser:      ${COLOR_GREEN}${DB_PASSWORD}${COLOR_RESET}"
        echo
        echo "  --- Datenbank-Admin (für die Ersteinrichtung) ---"
        echo -e "  Host:                 ${COLOR_GREEN}localhost${COLOR_RESET}"
        echo -e "  Datenbank-Benutzer:   ${COLOR_GREEN}${DB_ADMIN_USER}${COLOR_RESET}"
        echo -e "  Passwort:             ${COLOR_GREEN}${DB_ADMIN_PASSWORD}${COLOR_RESET}"
        echo
        echo "  --- Kivitendo Konfigurationsdatei (kivitendo.conf) ---"
        echo -e "  Benutzer:             ${COLOR_GREEN}${DB_USER}${COLOR_RESET}"
        echo -e "  Passwort:             ${COLOR_GREEN}${DB_PASSWORD}${COLOR_RESET}"
        echo -e "  Datenbank:            ${COLOR_GREEN}${DB_NAME}${COLOR_RESET}"
        echo "------------------------------------------------------------------"
    fi
}

# Skript ausführen
main