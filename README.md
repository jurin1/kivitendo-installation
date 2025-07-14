````markdown
# Kivitendo Easy Installer 🚀

Dieses Projekt stellt ein automatisiertes Installations-Skript bereit, um die Open-Source-ERP-Software [Kivitendo](https://kivitendo.de/) schnell und unkompliziert auf einem Debian- oder Ubuntu-System zu installieren. Das Skript ist primär für den Einsatz in einem Proxmox LXC-Container optimiert, funktioniert aber auch auf jeder anderen frischen Server- oder VM-Installation.

Das Ziel ist es, den gesamten Prozess – von der Systemvorbereitung bis zur lauffähigen Kivitendo-Anwendung – mit einem einzigen Befehl zu automatisieren.

## ✨ Features

*   ** vollautomatische Installation:** Führt alle notwendigen Schritte ohne manuelle Eingriffe durch.
*   ** interaktiv & benutzerfreundlich:** Fragt nach notwendigen Informationen (z.B. Passwort, Domain) und gibt verständliche, farbige Statusmeldungen aus.
*   ** flexible Versionsauswahl:** Lässt dich die zu installierende Kivitendo-Version dynamisch von GitHub auswählen.
*   ** sicherheitsbewusst:** Verwendet sichere, zufällige Passwörter als Standard, konfiguriert die Datenbank-Authentifizierung korrekt und vermeidet unsichere Voreinstellungen.
*   ** modular & wartbar:** Der Installationsprozess ist in logische Einzelschritte und Skripte unterteilt, was die Anpassung und Wartung erleichtert.
*   ** idempotent (Robust):** Die Skripte können meist mehrmals ausgeführt werden, ohne Fehler zu verursachen (z.B. wird ein bereits existierender DB-Benutzer nicht neu angelegt).
*   ** finale Zusammenfassung:** Am Ende der Installation erhältst du eine übersichtliche Zusammenfassung aller wichtigen Zugangsdaten und URLs.

## ⚙️ Systemanforderungen

*   **Betriebssystem:** Ein frisches System mit:
    *   **Debian 11 (Bullseye)** oder **Debian 12 (Bookworm)**
    *   **Ubuntu 20.04 (Focal)** oder **Ubuntu 22.04 (Jammy)**
*   **Berechtigungen:** Du benötigst `root`-Rechte oder einen Benutzer mit `sudo`-Berechtigungen.
*   **Internetverbindung:** Eine aktive Internetverbindung ist erforderlich, um Pakete und den Kivitendo-Quellcode herunterzuladen.

## ⚡ Schnellstart: Installation

Führe die folgenden vier Befehle auf deinem Server aus. Der gesamte Prozess wird danach automatisch ablaufen.

**1. Repository klonen:**
```bash
git clone https://github.com/DEIN-BENUTZERNAME/kivitendo-installer.git
```
*(Ersetze `DEIN-BENUTZERNAME` durch deinen tatsächlichen GitHub-Benutzernamen)*

**2. In das Verzeichnis wechseln:**
```bash
cd kivitendo-installer
```

**3. Das Skript ausführbar machen:**
```bash
chmod +x install.sh
```

**4. Das Installations-Skript starten:**
```bash
sudo ./install.sh
```

Lehne dich zurück und folge den Anweisungen auf dem Bildschirm. Das Skript wird dich durch die Konfiguration führen.

## 📜 Was das Skript im Detail tut

Die Installation ist in vier Hauptphasen unterteilt, die nacheinander ausgeführt werden:

1.  **Betriebssystem vorbereiten (`01_prepare_os.sh`)**
    *   Überprüft die Kompatibilität deines Betriebssystems.
    *   Führt ein vollständiges Systemupdate und -upgrade durch.
    *   Setzt die Zeitzone auf `Europe/Berlin`.
    *   Konfiguriert die System-Locales auf `de_DE.UTF-8`.

2.  **PostgreSQL installieren & konfigurieren (`02_install_postgres.sh`)**
    *   Installiert den PostgreSQL-Server.
    *   Fragt nach einem sicheren Passwort für die Datenbank-Administration.
    *   Setzt das Passwort für den `postgres`-Admin-Benutzer (wird für das Kivitendo-Setup benötigt).
    *   Erstellt einen dedizierten `kivitendo`-Datenbankbenutzer und eine `kivitendo`-Datenbank mit UTF-8-Kodierung.
    *   Konfiguriert die `pg_hba.conf` für sichere `md5`-Authentifizierung.
    *   Speichert die Zugangsdaten sicher für die nächsten Schritte.

3.  **Apache2 installieren & konfigurieren (`03_install_apache.sh`)**
    *   Installiert den Apache2-Webserver und das `mod_fcgid`-Modul.
    *   Aktiviert die benötigten Module `proxy_fcgi` und `rewrite`.
    *   Fragt nach einem Servernamen (z.B. `kivitendo.local`), unter dem die Anwendung erreichbar sein soll.
    *   Erstellt eine saubere Virtual-Host-Konfiguration speziell für Kivitendo.
    *   Aktiviert die Kivitendo-Seite und deaktiviert die Apache-Standardseite.

4.  **Kivitendo-Anwendung installieren (`04_install_kivitendo.sh`)**
    *   Installiert alle benötigten Perl-Pakete und Systemabhängigkeiten.
    *   Ruft die neuesten Versionen von Kivitendo via GitHub-API ab und lässt dich interaktiv eine Version auswählen.
    *   Kopiert den Kivitendo-Quellcode via `git` in das Web-Verzeichnis (`/var/www/kivitendo`).
    *   Füllt die `kivitendo.conf` automatisch mit den korrekten Datenbank-Zugangsdaten.
    *   Setzt die notwendigen Dateiberechtigungen für den Webserver.

## ✅ Nach der Installation

Wenn das Skript erfolgreich durchgelaufen ist, siehst du eine **Zusammenfassung** mit allen wichtigen Informationen.

1.  **DNS- oder Hosts-Eintrag erstellen:**
    Damit du Kivitendo im Browser aufrufen kannst, musst du den bei der Installation gewählten Servernamen auf die IP-Adresse deines Servers zeigen lassen. Füge dazu auf deinem **lokalen Computer** eine Zeile zur `hosts`-Datei hinzu:
    ```
    # Beispiel:
    192.168.1.100  kivitendo.local
    ```
    *   **Windows:** `C:\Windows\System32\drivers\etc\hosts`
    *   **Linux/macOS:** `/etc/hosts`

2.  **Kivitendo-Setup im Browser aufrufen:**
    Öffne deinen Webbrowser und gehe zu der Adresse, die in der Zusammenfassung angezeigt wird (z.B. `http://kivitendo.local`).

3.  **Datenbank einrichten:**
    Du wirst vom Kivitendo-Setup-Assistenten begrüßt. Gib hier die **PostgreSQL-Admin-Daten** ein, die in der Zusammenfassung angezeigt wurden (Benutzer: `postgres`, und das von dir gewählte Passwort), um die Datenbank zu initialisieren.

Viel Erfolg!

## 🔧 Anpassungen

*   **Perl-Pakete:** Du kannst die Liste der zu installierenden Perl-Pakete einfach anpassen, indem du die Datei `scripts/lib/perl_modules.txt` bearbeitest.

## 📄 Lizenz

Dieses Projekt steht unter der MIT-Lizenz. Siehe die `LICENSE`-Datei für weitere Details.
````
