#!/bin/bash

set -e
source "$(dirname "$0")/lib/common.sh"

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Starte Apache2 Installation und Konfiguration..."

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Installiere Apache2 und das FCGID-Modul..."
if sudo apt-get install -y apache2 libapache2-mod-fcgid &> /dev/null; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Apache2 und benötigte Module erfolgreich installiert."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler bei der Installation der Apache2-Pakete."
    exit 1
fi

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Aktiviere benötigte Apache-Module (proxy_fcgi, rewrite, fcgid)..."
if sudo a2enmod proxy_fcgi rewrite fcgid &> /dev/null; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Benötigte Module aktiviert."
else
    print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Module waren eventuell schon aktiviert, fahre fort."
fi

# NEU: FCGID-Konfiguration optimieren
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

# Kivitendo Virtual Host konfigurieren
KIVI_WEB_DIR="/var/www/kivitendo"
APACHE_CONF_PATH="/etc/apache2/sites-available/kivitendo.conf"
SERVER_NAME=""
read -p "Bitte gib den gewünschten ServerNamen (Domain) für Kivitendo an [Standard: kivitendo.local]: " USER_INPUT_NAME
[ -z "$USER_INPUT_NAME" ] && SERVER_NAME="kivitendo.local" || SERVER_NAME=$USER_INPUT_NAME
print_message "${COLOR_BLUE}" "${ICON_INFO}" "ServerName wird auf '${SERVER_NAME}' gesetzt."

sudo mkdir -p "${KIVI_WEB_DIR}"
sudo chown www-data:www-data "${KIVI_WEB_DIR}"

# VERBESSERT: Virtual Host Konfiguration mit Sicherheitsregeln
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Erstelle Apache Virtual Host Konfiguration mit Sicherheitsregeln..."
sudo tee "${APACHE_CONF_PATH}" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName ${SERVER_NAME}
    DocumentRoot ${KIVI_WEB_DIR}

    ErrorLog \${APACHE_LOG_DIR}/kivitendo-error.log
    CustomLog \${APACHE_LOG_DIR}/kivitendo-access.log combined

    RewriteEngine On
    RewriteRule ^/(?!stylesheets/|javascripts/|images/|doc/)(.*) /controller.pl/\$1 [L,QSA]

    <Directory ${KIVI_WEB_DIR}>
        Options +ExecCGI
        AllowOverride All
        Require all granted
    </Directory>

    # WICHTIG: Verhindere Zugriff auf sensible Verzeichnisse
    <DirectoryMatch "^${KIVI_WEB_DIR}/(\.git|config)">
        Require all denied
    </DirectoryMatch>

    <FilesMatch "\.pl$">
        SetHandler fcgid-script
    </FilesMatch>
</VirtualHost>
EOF
print_message "${COLOR_GREEN}" "${ICON_OK}" "Virtual Host Konfigurationsdatei erfolgreich erstellt."

sudo a2dissite 000-default.conf &> /dev/null
sudo a2ensite kivitendo.conf &> /dev/null

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

CONFIG_FILE_ABSOLUTE=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/../kivitendo.conf
echo "export KIVI_SERVER_NAME='${SERVER_NAME}'" >> "${CONFIG_FILE_ABSOLUTE}"
print_message "${COLOR_GREEN}" "${ICON_OK}" "Apache2-Konfiguration abgeschlossen!"```

#### Korrigiertes Skript: `04_install_kivitendo.sh`

Dieses Skript füllt jetzt alle notwendigen Konfigurationsparameter, erstellt das `webdav`-Verzeichnis und richtet den Task-Server ein.

```bash
#!/bin/bash

set -e
source "$(dirname "$0")/lib/common.sh"

# ... (Alle Teile bis zur Konfiguration bleiben gleich) ...
KIVI_WEB_DIR="/var/www/kivitendo"
SCRIPT_DIR_ABSOLUTE=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
CONFIG_FILE_ABSOLUTE="${SCRIPT_DIR_ABSOLUTE}/../kivitendo.conf"
# ... (Paketinstallation, Versionsauswahl, git clone/checkout) ...
# ...
# ...

# 4. Kivitendo konfigurieren (STARK ERWEITERT)
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Konfiguriere Kivitendo..."
cd "${KIVI_WEB_DIR}"
sudo ln -sf dispatcher.fcgi controller.pl

# NEU: Erstelle WebDAV-Verzeichnis
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
sudo sed -i "s/#admin_password =/admin_password = ${DB_ADMIN_PASSWORD}/" config/kivitendo.conf
sudo sed -i "s/#default_manager = german/default_manager = german/" config/kivitendo.conf
sudo sed -i "s/#run_as = www-data/run_as = www-data/" config/kivitendo.conf

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Setze Dateiberechtigungen für den Webserver..."
sudo chown -R www-data:www-data "${KIVI_WEB_DIR}"

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

print_message "${COLOR_GREEN}" "${ICON_OK}" "Kivitendo-Anwendungs-Konfiguration abgeschlossen!"