#!/bin/bash

set -e
source "$(dirname "$0")/lib/common.sh"

KIVI_WEB_DIR="/var/www/kivitendo"
PERL_PACKAGES_FILE="$(dirname "$0")/lib/perl_modules.txt"
SCRIPT_DIR_ABSOLUTE=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CONFIG_FILE_ABSOLUTE="${SCRIPT_DIR_ABSOLUTE}/../kivitendo.conf"

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Starte Kivitendo-Anwendungs-Installation..."

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Installiere benötigte System- und Perl-Pakete..."
if sudo apt-get update && xargs -a <(grep -vE '^\s*#|^\s*$' "${PERL_PACKAGES_FILE}") -r -- sudo apt-get install -y &> /dev/null; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Alle Abhängigkeiten erfolgreich installiert."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler bei der Installation der Abhängigkeiten."
    exit 1
fi

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Lade verfügbare Kivitendo-Versionen von GitHub..."
TAGS=($(curl -s https://api.github.com/repos/kivitendo/kivitendo-erp/tags | jq -r '.[].name' | head -n 6))
if [ ${#TAGS[@]} -eq 0 ]; then
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Konnte keine Versionen von GitHub abrufen."
    exit 1
fi
echo -e "${COLOR_YELLOW}Bitte wähle die zu installierende Kivitendo-Version:${COLOR_RESET}"
echo "  [0] Neueste stabile Version: ${TAGS[0]}"
for i in {1..5}; do
  [ -n "${TAGS[$i]}" ] && echo "  [${i}] Ältere Version:        ${TAGS[$i]}"
done
echo "  [6] Manuell eine andere Version eingeben (z.B. release-3.9.2)"
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
        read -p "Gib den gewünschten Versions-Tag ein: " MANUAL_TAG
        if [ -z "$MANUAL_TAG" ]; then exit 1; fi
        SELECTED_TAG=$MANUAL_TAG
        ;;
    *)
        print_message "${COLOR_RED}" "${ICON_ERROR}" "Ungültige Auswahl. Abbruch."
        exit 1
        ;;
esac
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Ausgewählte Version: ${SELECTED_TAG}"

if [ ! -d "${KIVI_WEB_DIR}/.git" ]; then
    print_message "${COLOR_BLUE}" "${ICON_INFO}" "Klone Kivitendo-Repository..."
    sudo git clone "https://github.com/kivitendo/kivitendo-erp.git" "${KIVI_WEB_DIR}"
fi
cd "${KIVI_WEB_DIR}"
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Setze Git-Verzeichnis als sicher..."
sudo git config --global --add safe.directory "${KIVI_WEB_DIR}"
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Aktualisiere Versionen vom Server..."
sudo git fetch --all --tags
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Wechsle zur Version '${SELECTED_TAG}'..."
if sudo git checkout "${SELECTED_TAG}"; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Erfolgreich zur Version ${SELECTED_TAG} gewechselt."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Konnte Version '${SELECTED_TAG}' nicht auschecken."
    exit 1
fi

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Konfiguriere Kivitendo..."
sudo ln -sf dispatcher.fcgi controller.pl
sudo mkdir -p "${KIVI_WEB_DIR}/webdav"
if [ ! -f "$CONFIG_FILE_ABSOLUTE" ]; then
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Haupt-Konfigurationsdatei '${CONFIG_FILE_ABSOLUTE}' nicht gefunden!"
    exit 1
fi
source "${CONFIG_FILE_ABSOLUTE}"
sudo cp config/kivitendo.conf.default config/kivitendo.conf

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Setze Konfigurationswerte..."
sudo sed -i "s#^\(host\s*=\s*\).*#host     = localhost#" config/kivitendo.conf
sudo sed -i "s#^\(port\s*=\s*\).*#port     = 5432#" config/kivitendo.conf
sudo sed -i "s#^\(db\s*=\s*\).*#db       = ${DB_NAME}#" config/kivitendo.conf
sudo sed -i "s#^\(user\s*=\s*\).*#user     = ${DB_USER}#" config/kivitendo.conf
sudo sed -i "s#^\(password\s*=\s*\).*#password = ${DB_PASSWORD}#" config/kivitendo.conf
sudo sed -i "s#^\(admin_password\s*=\s*\).*#admin_password = ${DB_ADMIN_PASSWORD}#" config/kivitendo.conf
sudo sed -i "s#^\(default_manager\s*=\s*\).*#default_manager = german#" config/kivitendo.conf
sudo sed -i "s#^\(run_as\s*=\s*\).*#run_as = www-data#" config/kivitendo.conf
print_message "${COLOR_GREEN}" "${ICON_OK}" "kivitendo.conf erfolgreich konfiguriert."

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Setze Dateiberechtigungen..."
sudo chown -R www-data:www-data "${KIVI_WEB_DIR}"

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Richte den Kivitendo Task Server ein..."
SERVICE_FILE_SOURCE="scripts/boot/systemd/kivitendo-task-server.service"
SERVICE_FILE_DEST="/etc/systemd/system/kivitendo-task-server.service"
if [ -f "${SERVICE_FILE_SOURCE}" ]; then
    sudo cp "${SERVICE_FILE_SOURCE}" "${SERVICE_FILE_DEST}"
    print_message "${COLOR_BLUE}" "${ICON_INFO}" "Passe Pfade in der Service-Datei an..."
    sudo sed -i "s#ExecStart=/usr/bin/perl /var/www/kivitendo-erp/scripts/task_server.pl#ExecStart=/usr/bin/perl ${KIVI_WEB_DIR}/scripts/task_server.pl#" "${SERVICE_FILE_DEST}"
    sudo sed -i "s#WorkingDirectory=/var/www/kivitendo-erp#WorkingDirectory=${KIVI_WEB_DIR}#" "${SERVICE_FILE_DEST}"
    sudo systemctl daemon-reload
    if sudo systemctl enable kivitendo-task-server.service --now; then
        print_message "${COLOR_GREEN}" "${ICON_OK}" "Kivitendo Task Server wurde installiert und gestartet."
    else
        print_message "${COLOR_RED}" "${ICON_ERROR}" "Der Kivitendo Task Server konnte nicht gestartet werden."
    fi
else
    print_message "${COLOR_YELLOW}" "${ICON_WARN}" "kivitendo-task-server.service Datei nicht gefunden."
fi

print_message "${COLOR_GREEN}" "✅ Kivitendo-Anwendungs-Konfiguration abgeschlossen!"