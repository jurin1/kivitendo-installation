#!/bin/bash
source "$(dirname "$0")/lib/common.sh"

# Das Skript bei einem Fehler sofort beenden
set -e

# Die Hilfsfunktionen und Variablen werden vom Hauptskript geerbt.

# --- Skript-Start ---
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Starte PostgreSQL Installation und Konfiguration..."

# 1. PostgreSQL installieren
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Installiere PostgreSQL-Pakete..."
if sudo apt-get install -y postgresql postgresql-client &> /dev/null; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "PostgreSQL erfolgreich installiert."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler bei der Installation von PostgreSQL."
    exit 1
fi

# 2. Passwort für Datenbank-Admin und Kivitendo-Benutzer abfragen
DB_USER="kivitendo"
DB_NAME="kivitendo"
DB_ADMIN_USER="postgres"
DEFAULT_PASS=$(openssl rand -base64 16)
KIVI_DB_PASSWORD=""

print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Für die Kivitendo-Installation wird ein Admin-Passwort für die PostgreSQL-Datenbank benötigt."
print_message "${COLOR_YELLOW}" "Dieses Passwort wird für den Admin-Benutzer '${DB_ADMIN_USER}' und den Anwendungs-Benutzer '${DB_USER}' gesetzt."
read -p "Bitte gib ein sicheres Passwort ein oder drücke [Enter], um dieses zufällige zu verwenden (${DEFAULT_PASS}): " USER_INPUT_PASS

if [ -z "$USER_INPUT_PASS" ]; then
    KIVI_DB_PASSWORD=$DEFAULT_PASS
    print_message "${COLOR_BLUE}" "${ICON_INFO}" "Ein zufälliges Passwort wird verwendet."
else
    KIVI_DB_PASSWORD=$USER_INPUT_PASS
    print_message "${COLOR_BLUE}" "${ICON_INFO}" "Das eingegebene Passwort wird verwendet."
fi

# 3. Passwörter in der Datenbank setzen
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Setze Passwörter für die Datenbank-Benutzer..."
sudo -u postgres psql -c "ALTER USER ${DB_ADMIN_USER} WITH PASSWORD '${KIVI_DB_PASSWORD}';"
print_message "${COLOR_GREEN}" "${ICON_OK}" "Passwort für Admin-Benutzer '${DB_ADMIN_USER}' erfolgreich gesetzt."

# 4. Datenbank und Anwendungs-Benutzer erstellen
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Erstelle Datenbank '${DB_NAME}' und Benutzer '${DB_USER}'..."
if sudo -u postgres psql -t -c '\du' | cut -d \| -f 1 | grep -qw $DB_USER; then
    print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Benutzer '${DB_USER}' existiert bereits. Ändere Passwort."
    sudo -u postgres psql -c "ALTER USER ${DB_USER} WITH PASSWORD '${KIVI_DB_PASSWORD}';"
else
    sudo -u postgres psql -c "CREATE USER ${DB_USER} WITH PASSWORD '${KIVI_DB_PASSWORD}';"
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Benutzer '${DB_USER}' erfolgreich erstellt."
fi

if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw $DB_NAME; then
   print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Datenbank '${DB_NAME}' existiert bereits. Überspringe Erstellung."
else
   sudo -u postgres psql -c "CREATE DATABASE ${DB_NAME} OWNER ${DB_USER} ENCODING 'UTF8' TEMPLATE template0 LC_COLLATE 'de_DE.UTF-8' LC_CTYPE 'de_DE.UTF-8';"
   print_message "${COLOR_GREEN}" "${ICON_OK}" "Datenbank '${DB_NAME}' erfolgreich erstellt."
fi

# 5. NEU: Überprüfung der Datenbank-Kodierung
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Überprüfe die Kodierung der erstellten Datenbank..."
DB_CHECK_RESULT=$(sudo -u postgres psql -t -d ${DB_NAME} -c "SELECT pg_encoding_to_char(encoding) FROM pg_database WHERE datname = '${DB_NAME}';" | xargs)

if [[ "${DB_CHECK_RESULT}" == "UTF8" ]]; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Datenbank-Kodierung ist korrekt auf UTF-8 gesetzt."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler: Datenbank-Kodierung ist '${DB_CHECK_RESULT}' anstatt UTF-8."
    exit 1
fi

# 6. Authentifizierung konfigurieren (pg_hba.conf)
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Konfiguriere PostgreSQL-Authentifizierung (pg_hba.conf)..."
PG_HBA_CONF_PATH=$(sudo -u postgres psql -t -c "SHOW hba_file;" | xargs)

if [ -z "$PG_HBA_CONF_PATH" ]; then
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Konnte den Pfad zur pg_hba.conf nicht finden."
    exit 1
fi
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Dynamischer Pfad gefunden: ${PG_HBA_CONF_PATH}"

# Ersetze "password" durch "md5" für mehr Sicherheit
AUTH_LINE_LOCAL="local   all             all                                     md5"
AUTH_LINE_HOST="host    all             all             127.0.0.1/32            md5"

# Wir stellen sicher, dass die Authentifizierungsmethode auf md5 steht.
# Wir ersetzen die Standardeinträge, anstatt neue hinzuzufügen, um die Datei sauber zu halten.
sudo sed -i -E "s/^(local\s+all\s+all\s+).*/${AUTH_LINE_LOCAL}/" "${PG_HBA_CONF_PATH}"
sudo sed -i -E "s/^(host\s+all\s+all\s+127\.0\.0\.1\/32\s+).*/${AUTH_LINE_HOST}/" "${PG_HBA_CONF_PATH}"
print_message "${COLOR_GREEN}" "${ICON_OK}" "Authentifizierungsmethoden auf 'md5' aktualisiert."

# 7. PostgreSQL neustarten
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Starte PostgreSQL-Dienst neu, um Änderungen zu übernehmen..."
if sudo systemctl restart postgresql; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "PostgreSQL-Dienst erfolgreich neu gestartet."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler beim Neustart von PostgreSQL."
    exit 1
fi

# 8. Zugangsdaten für spätere Schritte speichern
CONFIG_FILE="$(dirname "$0")/../kivitendo.conf"
{
  echo "# Kivitendo Konfiguration (automatisch generiert)"
  echo "export DB_ADMIN_USER='${DB_ADMIN_USER}'"
  echo "export DB_ADMIN_PASSWORD='${KIVI_DB_PASSWORD}'"
  echo "export DB_USER='${DB_USER}'"
  echo "export DB_PASSWORD='${KIVI_DB_PASSWORD}'"
  echo "export DB_NAME='${DB_NAME}'"
} > "${CONFIG_FILE}"
chmod 600 "${CONFIG_FILE}"

print_message "${COLOR_GREEN}" "${ICON_OK}" "PostgreSQL-Konfiguration abgeschlossen!"
print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Die Zugangsdaten wurden sicher in 'kivitendo.conf' gespeichert."```
