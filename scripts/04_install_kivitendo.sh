#!/bin/bash

set -e

# Lade die gemeinsame Bibliothek für Farben und Funktionen
source "$(dirname "$0")/lib/common.sh"

# --- Konfiguration ---
KIVI_WEB_DIR="/var/www/kivitendo"
PERL_PACKAGES_FILE="$(dirname "$0")/lib/perl_modules.txt"
SCRIPT_DIR_ABSOLUTE=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CONFIG_FILE_ABSOLUTE="${SCRIPT_DIR_ABSOLUTE}/../kivitendo.conf"

# --- Skript-Start ---
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Starte Kivitendo-Anwendungs-Installation..."

# 1. Abhängigkeiten installieren
# ... (dieser Teil bleibt unverändert) ...
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Installiere benötigte System- und Perl-Pakete..."
if sudo apt-get update && xargs -a <(grep -vE '^\s*#|^\s*$' "${PERL_PACKAGES_FILE}") -r -- sudo apt-get install -y &> /dev/null; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Alle Abhängigkeiten erfolgreich installiert."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler bei der Installation der Abhängigkeiten."
    exit 1
fi

# 2. Version auswählen
# ... (dieser Teil bleibt unverändert) ...
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Lade verfügbare Kivitendo-Versionen von GitHub..."
TAGS=($(curl -s https://api.github.com/repos/kivitendo/kivitendo-erp/tags | jq -r '.[].name' | head -n 6))
# ... (restliche Versionsauswahl) ...
# ...
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Ausgewählte Version: ${SELECTED_TAG}"


# 3. Git-Repository holen
# ... (dieser Teil bleibt unverändert) ...
if [ ! -d "${KIVI_WEB_DIR}/.git" ]; then
    print_message "${COLOR_BLUE}" "${ICON_INFO}" "Klone Kivitendo-Repository nach ${KIVI_WEB_DIR}..."
    sudo git clone "https://github.com/kivitendo/kivitendo-erp.git" "${KIVI_WEB_DIR}"
fi
cd "${KIVI_WEB_DIR}"
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Setze Git-Verzeichnis als sicher für den aktuellen Benutzer..."
sudo git config --global --add safe.directory "${KIVI_WEB_DIR}"
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Aktualisiere alle Versionen vom Server (git fetch)..."
sudo git fetch --all --tags
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Wechsle zur Version '${SELECTED_TAG}'..."
if sudo git checkout "${SELECTED_TAG}"; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Erfolgreich zur Version ${SELECTED_TAG} gewechselt."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Konnte Version '${SELECTED_TAG}' nicht auschecken."
    exit 1
fi

# 4. Kivitendo konfigurieren (STARK ERWEITERT)
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Konfiguriere Kivitendo..."
sudo ln -sf dispatcher.fcgi controller.pl

# NEU: Erstelle WebDAV-Verzeichnis für Dokumenten-Uploads
sudo mkdir -p "${KIVI_WEB_DIR}/webdav"

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Erstelle kivitendo.conf aus Vorlage und fülle alle Zugangsdaten ein..."
if [ ! -f "$CONFIG_FILE_ABSOLUTE" ]; then
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Haupt-Konfigurationsdatei '${CONFIG_FILE_ABSOLUTE}' nicht gefunden!"
    exit 1
fi
source "${CONFIG_FILE_ABSOLUTE}"

sudo cp config/kivitendo.conf.default config/kivitendo.conf
# Datenbank-Zugangsdaten füllen
sudo sed -i "s/user      = postgres/user      = ${DB_USER}/" config/kivitendo.conf
sudo sed -i "s/password  =/password  = ${DB_PASSWORD}/" config/kivitendo.conf
sudo sed -i "s/db        = kivitendo/db        = ${DB_NAME}/" config/kivitendo.conf

# NEU: Admin-Passwort und System-Einstellungen füllen
# Wir verwenden das DB-Admin-Passwort für den Kivitendo-Admin zur Vereinfachung
sudo sed -i "s/#admin_password =/admin_password = ${DB_ADMIN_PASSWORD}/" config/kivitendo.conf
sudo sed -i "s/#default_manager = german/default_manager = german/" config/kivitendo.conf
sudo sed -i "s/#run_as = www-data/run_as = www-data/" config/kivitendo.conf
print_message "${COLOR_GREEN}" "${ICON_OK}" "kivitendo.conf erfolgreich konfiguriert."

# Setze globale Dateiberechtigungen, bevor Skripte als www-data ausgeführt werden
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Setze Dateiberechtigungen für den Webserver..."
sudo chown -R www-data:www-data "${KIVI_WEB_DIR}"

# Kompiliere die Templates, um Laufzeitfehler zu vermeiden
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Kompiliere Kivitendo-Templates..."
if sudo -u www-data /usr/bin/perl ./scripts/compile_templates.pl; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Templates erfolgreich kompiliert."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler beim Kompilieren der Templates."
fi

# NEU: Kivitendo Task Server als Systemd-Dienst einrichten
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Richte den Kivitendo Task Server als Hintergrunddienst ein..."
if [ -f "scripts/boot/systemd/kivitendo-task-server.service" ]; then
    sudo cp scripts/boot/systemd/kivitendo-task-server.service /etc/systemd/system/
    sudo systemctl daemon-reload
    sudo systemctl enable kivitendo-task-server.service --now
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Kivitendo Task Server wurde installiert und gestartet."
else
    print_message "${COLOR_YELLOW}" "${ICON_WARN}" "kivitendo-task-server.service Datei nicht gefunden. Überspringe Einrichtung."
fi

print_message "${COLOR_GREEN}" "✅ Kivitendo-Anwendungs-Konfiguration abgeschlossen!"