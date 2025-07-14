#!/bin/bash
source "$(dirname "$0")/lib/common.sh"
set -e

# --- Konfiguration ---
KIVI_REPO="https://github.com/kivitendo/kivitendo-erp.git"
KIVI_WEB_DIR="/var/www/kivitendo"
PERL_PACKAGES_FILE="$(dirname "$0")/lib/perl_modules.txt"
CONFIG_FILE="$(dirname "$0")/../kivitendo.conf"

# --- Skript-Start ---
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Starte Kivitendo-Installation..."

# 1. Kivitendo-Abhängigkeiten installieren
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Installiere benötigte System- und Perl-Pakete..."
# Lese Pakete aus der Datei und installiere sie
if sudo apt-get update && xargs -a <(grep -vE '^\s*#|^\s*$' "${PERL_PACKAGES_FILE}") -r -- sudo apt-get install -y &> /dev/null; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Alle Abhängigkeiten erfolgreich installiert."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler bei der Installation der Abhängigkeiten."
    exit 1
fi

# 2. Kivitendo-Version auswählen
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Lade verfügbare Kivitendo-Versionen von GitHub..."
# GitHub API aufrufen und die Namen der letzten 6 Tags holen
# Das -s bei curl unterdrückt die Fortschrittsanzeige
TAGS=($(curl -s https://api.github.com/repos/kivitendo/kivitendo-erp/tags | jq -r '.[].name' | head -n 6))

if [ ${#TAGS[@]} -eq 0 ]; then
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Konnte keine Versionen von GitHub abrufen. Überprüfe die Internetverbindung."
    exit 1
fi

echo -e "${COLOR_YELLOW}Bitte wähle die zu installierende Kivitendo-Version:${COLOR_RESET}"
echo "  [0] Neueste stabile Version: ${TAGS[0]}"
for i in {1..5}; do
  echo "  [${i}] Ältere Version:        ${TAGS[$i]}"
done
echo "  [6] Manuell eine andere Version eingeben (z.B. 3.8.0)"

read -p "Deine Wahl [0-6]: " VERSION_CHOICE

SELECTED_TAG=""
case $VERSION_CHOICE in
    0) SELECTED_TAG=${TAGS[0]} ;;
    1) SELECTED_TAG=${TAGS[1]} ;;
    2) SELECTED_TAG=${TAGS[2]} ;;
    3) SELECTED_TAG=${TAGS[3]} ;;
    4) SELECTED_TAG=${TAGS[4]} ;;
    5) SELECTED_TAG=${TAGS[5]} ;;
    6)
        read -p "Gib den gewünschten Versions-Tag ein (siehe https://github.com/kivitendo/kivitendo-erp/tags): " MANUAL_TAG
        if [ -z "$MANUAL_TAG" ]; then
            print_message "${COLOR_RED}" "${ICON_ERROR}" "Kein Tag eingegeben. Abbruch."
            exit 1
        fi
        SELECTED_TAG=$MANUAL_TAG
        ;;
    *)
        print_message "${COLOR_RED}" "${ICON_ERROR}" "Ungültige Auswahl. Abbruch."
        exit 1
        ;;
esac

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Ausgewählte Version: ${SELECTED_TAG}"

# 3. Kivitendo aus dem Git-Repository holen
if [ -d "${KIVI_WEB_DIR}/.git" ]; then
    print_message "${COLOR_BLUE}" "${ICON_INFO}" "Bestehendes Kivitendo-Verzeichnis gefunden. Aktualisiere..."
    cd "${KIVI_WEB_DIR}"
    sudo git fetch --all --tags
else
    print_message "${COLOR_BLUE}" "${ICON_INFO}" "Klone Kivitendo-Repository nach ${KIVI_WEB_DIR}..."
    sudo git clone "${KIVI_REPO}" "${KIVI_WEB_DIR}"
    cd "${KIVI_WEB_DIR}"
fi

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Wechsle zur Version '${SELECTED_TAG}'..."
if sudo git checkout "tags/${SELECTED_TAG}"; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Erfolgreich zur Version ${SELECTED_TAG} gewechselt."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Konnte Version '${SELECTED_TAG}' nicht auschecken. Ist der Tag-Name korrekt?"
    exit 1
fi

# 4. Kivitendo konfigurieren
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Konfiguriere Kivitendo..."

# Symlink für den FCGI-Dispatcher erstellen
sudo ln -sf dispatcher.fcgi controller.pl

# Konfigurationsdatei aus Vorlage erstellen UND mit unseren Daten füllen
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Erstelle kivitendo.conf aus Vorlage und fülle Datenbank-Zugangsdaten ein..."
if [ ! -f "$CONFIG_FILE" ]; then
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Haupt-Konfigurationsdatei '${CONFIG_FILE}' nicht gefunden!"
    exit 1
fi
# Lade unsere gespeicherten Variablen
source "${CONFIG_FILE}"

# Ersetze die Platzhalter in der Vorlage mit unseren Werten
sudo cp config/kivitendo.conf.default config/kivitendo.conf
sudo sed -i "s/user      = postgres/user      = ${DB_USER}/" config/kivitendo.conf
sudo sed -i "s/password  =/password  = ${DB_PASSWORD}/" config/kivitendo.conf
sudo sed -i "s/db        = kivitendo/db        = ${DB_NAME}/" config/kivitendo.conf

# Berechtigungen für den Webserver setzen
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Setze Dateiberechtigungen für den Webserver..."
sudo chown -R www-data:www-data "${KIVI_WEB_DIR}"

print_message "${COLOR_GREEN}" "${ICON_OK}" "Kivitendo-Installation und -Konfiguration abgeschlossen!"