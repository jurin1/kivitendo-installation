#!/bin/bash
source "$(dirname "$0")/lib/common.sh"

# Das Skript bei einem Fehler sofort beenden
set -e

# Die Hilfsfunktionen und Variablen werden vom Hauptskript geerbt.

# --- Skript-Start ---
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Starte Apache2 Installation und Konfiguration..."

# 1. Benötigte Pakete installieren
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Installiere Apache2 und das FCGID-Modul..."
if sudo apt-get install -y apache2 libapache2-mod-fcgid &> /dev/null; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Apache2 und benötigte Module erfolgreich installiert."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler bei der Installation der Apache2-Pakete."
    exit 1
fi

# 2. Apache Module aktivieren
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Aktiviere benötigte Apache-Module (proxy_fcgi, rewrite)..."
if sudo a2enmod proxy_fcgi rewrite &> /dev/null; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Module 'proxy_fcgi' und 'rewrite' aktiviert."
else
    # a2enmod gibt manchmal eine Warnung aus, wenn schon aktiv, aber keinen Fehlercode.
    # Wir fangen hier nur echte Fehler ab.
    print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Module waren eventuell schon aktiviert, fahre fort."
fi

# 3. Kivitendo Virtual Host konfigurieren
KIVI_WEB_DIR="/var/www/kivitendo"
APACHE_CONF_PATH="/etc/apache2/sites-available/kivitendo.conf"
SERVER_NAME=""

print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Bitte gib den gewünschten ServerNamen (Domain) für Kivitendo an."
read -p "z.B. kivitendo.local oder kivitendo.meine-firma.de [Standard: kivitendo.local]: " USER_INPUT_NAME

if [ -z "$USER_INPUT_NAME" ]; then
    SERVER_NAME="kivitendo.local"
else
    SERVER_NAME=$USER_INPUT_NAME
fi
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Der ServerName wird auf '${SERVER_NAME}' gesetzt."

# Web-Verzeichnis für Kivitendo erstellen
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Erstelle Web-Verzeichnis: ${KIVI_WEB_DIR}"
sudo mkdir -p "${KIVI_WEB_DIR}"
sudo chown www-data:www-data "${KIVI_WEB_DIR}"

# Apache Konfigurationsdatei erstellen mit "Here-Document"
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Erstelle Apache Virtual Host Konfiguration..."
sudo tee "${APACHE_CONF_PATH}" > /dev/null <<EOF
<VirtualHost *:80>
    ServerName ${SERVER_NAME}
    DocumentRoot ${KIVI_WEB_DIR}

    ErrorLog \${APACHE_LOG_DIR}/kivitendo-error.log
    CustomLog \${APACHE_LOG_DIR}/kivitendo-access.log combined

    <Directory ${KIVI_WEB_DIR}>
        Options +ExecCGI
        AllowOverride All
        Require all granted
    </Directory>

    <FilesMatch "\.pl$">
        SetHandler fcgid-script
    </FilesMatch>

    RewriteEngine on
    RewriteRule ^/(?!stylesheets/|javascripts/|images/|doc/)(.*) /controller.pl/\$1 [L,QSA]
    Include conf-available/serve-cgi-bin.conf
</VirtualHost>
EOF

if [ -f "${APACHE_CONF_PATH}" ]; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Virtual Host Konfigurationsdatei erfolgreich erstellt."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Konnte die Virtual Host Konfigurationsdatei nicht erstellen."
    exit 1
fi

# 4. Standard-Seite deaktivieren und Kivitendo-Seite aktivieren
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Aktiviere die Kivitendo-Website und deaktiviere die Standard-Seite..."
sudo a2dissite 000-default.conf &> /dev/null
if sudo a2ensite kivitendo.conf &> /dev/null; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Kivitendo-Website erfolgreich aktiviert."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler beim Aktivieren der Kivitendo-Website."
    exit 1
fi

# 5. Apache Konfiguration testen und Dienst neustarten
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Teste die Apache2-Konfiguration..."
if ! sudo apachectl configtest; then
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Apache2 Konfigurationstest fehlgeschlagen! Bitte überprüfe die Fehlermeldungen."
    exit 1
fi

print_message "${COLOR_BLUE}" "${ICON_INFO}" "Starte Apache2-Dienst neu, um Änderungen zu übernehmen..."
if sudo systemctl restart apache2; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Apache2-Dienst erfolgreich neu gestartet."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler beim Neustart von Apache2."
    exit 1
fi

# 6. ServerName für die finale Zusammenfassung speichern
CONFIG_FILE="$(dirname "$0")/../kivitendo.conf"
echo "export KIVI_SERVER_NAME='${SERVER_NAME}'" >> "${CONFIG_FILE}"

print_message "${COLOR_GREEN}" "${ICON_OK}" "Apache2-Konfiguration abgeschlossen!"
print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Deine Kivitendo-Installation wird unter http://${SERVER_NAME} erreichbar sein."
print_message "${COLOR_YELLOW}" "  Denke daran, '${SERVER_NAME}' in deiner lokalen 'hosts'-Datei oder im DNS auf die IP dieses Servers zeigen zu lassen."