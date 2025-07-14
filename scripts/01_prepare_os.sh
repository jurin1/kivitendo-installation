#!/bin/bash

# Das Skript bei einem Fehler sofort beenden
set -e

# Lade die gemeinsame Bibliothek für Farben und Funktionen
# Diese Zeile sollte hinzugefügt werden, falls noch nicht geschehen (siehe unsere letzte Diskussion)
source "$(dirname "$0")/lib/common.sh"

# --- Skript-Start ---
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Starte Vorbereitung des Betriebssystems..."

# 1. Überprüfung des Betriebssystems
# ... (Dieser Teil bleibt unverändert) ...
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Prüfe Betriebssystem-Kompatibilität..."

if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
    VERSION=$VERSION_ID
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Kann Betriebssystem nicht identifizieren. /etc/os-release nicht gefunden."
    exit 1
fi

SUPPORTED=false
if [[ "$OS" == "debian" && ( "$VERSION" == "11" || "$VERSION" == "12" ) ]]; then
    SUPPORTED=true
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Kompatibles System gefunden: Debian $VERSION"
elif [[ "$OS" == "ubuntu" && ( "$VERSION" == "20.04" || "$VERSION" == "22.04" ) ]]; then
    SUPPORTED=true
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Kompatibles System gefunden: Ubuntu $VERSION"
elif [[ "$OS" == "ubuntu" || "$OS" == "debian" ]]; then
    print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Dein Betriebssystem '$ID $VERSION_ID' wird nicht offiziell unterstützt."
    print_message "${COLOR_YELLOW}" "${ICON_WARN}" "Das Skript ist für Debian 11/12 und Ubuntu 20.04/22.04 optimiert."
    read -p "Drücke [Enter], um die Installation trotzdem fortzusetzen, oder [Strg+C] zum Abbrechen."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Inkompatibles Betriebssystem: $ID $VERSION_ID."
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Dieses Skript unterstützt nur Debian-basierte Systeme (Debian, Ubuntu)."
    exit 1
fi


# 2. System-Updates
# ... (Dieser Teil bleibt unverändert) ...
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Aktualisiere das System. Dies kann einige Minuten dauern..."
if sudo apt-get update && sudo apt-get upgrade -y && sudo apt-get autoremove -y; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "System erfolgreich aktualisiert."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler bei der Systemaktualisierung."
    exit 1
fi


# 3. Zeitzone und Locales konfigurieren (NEUER, ROBUSTERER TEIL)
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Konfiguriere Zeitzone und Locales..."

# Setze Zeitzone auf Europe/Berlin
if sudo timedatectl set-timezone Europe/Berlin; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Zeitzone auf Europe/Berlin gesetzt."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler beim Setzen der Zeitzone."
    exit 1
fi

# Installiere die notwendigen Locale-Pakete (locales-all ist der Schlüssel)
print_message "${COLOR_BLUE}" "${ICON_INFO}" "Installiere und konfiguriere Locale-Pakete..."
if sudo apt-get install -y locales locales-all &> /dev/null; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "Locale-Pakete sind installiert."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler bei der Installation der Locale-Pakete."
    exit 1
fi

# Stelle sicher, dass de_DE.UTF-8 in /etc/locale.gen aktiv ist
LOCALE_LINE="de_DE.UTF-8 UTF-8"
# Entkommentiere die Zeile, falls sie mit '#' beginnt
sudo sed -i "s/^# *${LOCALE_LINE}/${LOCALE_LINE}/" /etc/locale.gen
# Füge die Zeile hinzu, falls sie gar nicht existiert
if ! grep -q "^${LOCALE_LINE}" /etc/locale.gen; then
    echo "${LOCALE_LINE}" | sudo tee -a /etc/locale.gen > /dev/null
fi
print_message "${COLOR_GREEN}" "${ICON_OK}" "Locale 'de_DE.UTF-8' in /etc/locale.gen sichergestellt."

# Generiere die Locales
if sudo locale-gen; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "System-Locales erfolgreich neu generiert."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "Fehler beim Generieren der Locales."
    exit 1
fi

# Setze die System-Locale (sollte jetzt funktionieren)
if sudo update-locale LANG=de_DE.UTF-8; then
    print_message "${COLOR_GREEN}" "${ICON_OK}" "System-Locale auf 'de_DE.UTF-8' gesetzt."
else
    print_message "${COLOR_RED}" "${ICON_ERROR}" "FEHLER: Konnte die System-Locale trotz Korrekturmaßnahmen nicht setzen."
    exit 1
fi

# Exportiere die Variablen für die aktuelle Shell-Sitzung
export LANG=de_DE.UTF-8
export LC_ALL=de_DE.UTF-8

print_message "${COLOR_GREEN}" "${ICON_OK}" "Vorbereitung des Betriebssystems abgeschlossen!"