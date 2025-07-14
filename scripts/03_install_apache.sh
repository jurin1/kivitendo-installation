#!/bin/bash

set -e
source "$(dirname "$0")/lib/common.sh"

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Starte Apache2 Installation und Konfiguration..."

# ... (Installation und fcgid.conf bleiben unverändert) ...
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Installiere Apache2 und das FCGID-Modul..."
if sudo apt-get install -y apache2 libapache2-mod-fcgid &> /dev/null; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Apache2 und benötigte Module erfolgreich installiert."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler bei der Installation der Apache2-Pakete."
    exit 1
fi
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Aktiviere benötigte Apache-Module (rewrite, fcgid)..."
if sudo a2enmod rewrite fcgid &> /dev/null; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Benötigte Module aktiviert."
else
    print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Module waren eventuell schon aktiviert, fahre fort."
fi
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Optimiere FCGID-Konfiguration für lange Laufzeiten..."
sudo tee /etc/apache2/mods-available/fcgid.conf > /dev/null <<EOF
<IfModule mod_fcgid.c>
  AddHandler fcgid-script .fcgi
  FcgidConnectTimeout 20
  FcgidBusyTimeout 3600
  FcgidIOTimeout 600
  FcgidMaxRequestLen 314572800
</IfModule>
EOF
print_message "${COLOR_GREEN}" "${ICON_OK}" "FCGID-Konfiguration gespeichert."

# ... (Domain-Abfrage und Virtual-Host-Erstellung bleiben unverändert) ...
KIVI_WEB_DIR="/var/www/kivitendo"
APACHE_CONF_PATH="/etc/apache2/sites-available/kivitendo.conf"
SERVER_NAME=""
read -p "Bitte gib den gewünschten ServerNamen (Domain) für Kivitendo an [Standard: kivitendo.local]: " USER_INPUT_NAME
[ -z "$USER_INPUT_NAME" ] && SERVER_NAME="kivitendo.local" || SERVER_NAME=$USER_INPUT_NAME
print_message "${COLOR_BLUE}" "${ICON_INFO}" "ServerName wird auf '${SERVER_NAME}' gesetzt."
sudo mkdir -p "${KIVI_WEB_DIR}"
sudo chown www-data:www-data "${KIVI_WEB_DIR}"
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Erstelle minimalen Apache Virtual Host..."
sudo tee "${APACHE_CONF_PATH}" > /dev/null <<EOF
<VirtualHost *:80>
  ServerName ${SERVER_NAME}
  ServerAdmin webmaster@localhost
  DocumentRoot ${KIVI_WEB_DIR}

  ErrorLog \${APACHE_LOG_DIR}/kivitendo-error.log
  CustomLog \${APACHE_LOG_DIR}/kivitendo-access.log combined
</VirtualHost>
EOF
print_message "${COLOR_GREEN}" "${ICON_OK}" "Virtual Host Konfigurationsdatei erfolgreich erstellt."

# KORRIGIERTER TEIL: Prüfen, ob die Seiten existieren, bevor sie (de)aktiviert werden.
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Deaktiviere Standard-Seite und aktiviere Kivitendo-Seite..."
if [ -L /etc/apache2/sites-enabled/000-default.conf ]; then
    sudo a2dissite --quiet 000-default.conf
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Standard-Seite deaktiviert."
else
    print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Standard-Seite war bereits deaktiviert."
fi

if ! [ -L /etc/apache2/sites-enabled/kivitendo.conf ]; then
    sudo a2ensite --quiet kivitendo.conf
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Kivitendo-Seite aktiviert."
else
    print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Kivitendo-Seite war bereits aktiviert."
fi

# ... (Der Rest des Skripts bleibt unverändert) ...
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Füge Kivitendo-Konfiguration zur globalen apache2.conf hinzu..."
# Wir fügen einen Marker hinzu, um zu verhindern, dass die Konfiguration mehrfach hinzugefügt wird
CONF_MARKER="# Kivitendo Apache2 Konfiguration"
if ! sudo grep -qF "${CONF_MARKER}" /etc/apache2/apache2.conf; then
    sudo tee -a /etc/apache2/apache2.conf > /dev/null <<EOF

${CONF_MARKER}
AliasMatch ^/[^/]+\.pl\$ ${KIVI_WEB_DIR}/dispatcher.fcgi
Alias       /          ${KIVI_WEB_DIR}/
<Directory ${KIVI_WEB_DIR}/>
  AllowOverride All
  Options ExecCGI Includes FollowSymlinks
  Require all granted
</Directory>
<DirectoryMatch ${KIVI_WEB_DIR}/users>
  Require all denied
</DirectoryMatch>
<DirectoryMatch "${KIVI_WEB_DIR}/(\.git|config)/">
  Require all denied
</DirectoryMatch>
EOF
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Kivitendo-Konfiguration zu apache2.conf hinzugefügt."
else
    print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Kivitendo-Konfiguration existiert bereits in apache2.conf."
fi


print_message "${COLOR_BLUE}" "${ICON_INFO}" "Teste Apache2-Konfiguration..."
if ! sudo apachectl configtest; then
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Apache2 Konfigurationstest fehlgeschlagen!"
    exit 1
fi

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Starte Apache2-Dienst neu..."
if sudo systemctl restart apache2; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Apache2-Dienst erfolgreich neu gestartet."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler beim Neustart von Apache2."
    exit 1
fi

SCRIPT_DIR_ABSOLUTE=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CONFIG_FILE_ABSOLUTE="${SCRIPT_DIR_ABSOLUTE}/../kivitendo.conf"
echo "export KIVI_SERVER_NAME='${SERVER_NAME}'" >> "${CONFIG_FILE_ABSOLUTE}"
print_message "${COLOR_GREEN}" "✅ Apache2-Konfiguration abgeschlossen!"