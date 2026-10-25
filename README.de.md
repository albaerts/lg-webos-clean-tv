# lg-webos-clean-tv — Anleitung (Deutsch)

Ein sauberer LG-webOS-Fernseher: **eigener minimaler Home-Screen** (Hintergrundbild, Uhr, eine App-Reihe), **kein Werbebanner, keine
gesponserten Reihen, kein „Live on LG Channels“**, **LG-Werbe-, Telemetrie- und ACR-Hosts geblockt**, Werbeschalter aus. Mit einem Befehl rückgängig.

Getestet von A bis Z auf einem **LG OLED77C37LA (C3, 2023), webOS 11.2.0-3701 („webOS 26“), Oktober 2026**, gerootet mit Homebrew Channel.
Andere Modelle und Firmware-Stände weichen ab. Bitte die ganze Seite lesen, bevor du beginnst.

## Was du bekommst

| Vorher | Nachher |
|---|---|
| Werbebanner, Edit-Karte, App-Reihe, Recent Input, „Live on LG Channels“, „Trending now“, gesponserte Reihen | Hintergrundbild, Glas-Uhr, eine App-Reihe mit genau den Apps, die du willst |
| Werbe-, Telemetrie- und ACR-Beacons zu lgsmartad.com, cdpbeacon.lgtvcommon.com, … | Bei jedem Boot in `/etc/hosts` geblockt |
| Home-Promotion, Live-Promotion, LG-Channels-Autostart, UI-Transparenz | Aus, über LGs eigenen Einstellungsdienst (bleibt erhalten, kein Hack) |

Die schreibgeschützten Systempartitionen werden nicht verändert. Alles liegt in `/var/lib/webosbrew/cleantv` und wird beim Boot von zwei
Homebrew-Channel-Hooks angewendet. `uninstall.sh` stellt LGs Home wieder her.

## Voraussetzungen

1. Ein **gerooteter** LG-webOS-TV mit **Homebrew Channel** und **SSH**. Root-Anleitungen und die Tabelle „kann ich meinen TV rooten“:
   [cani.rootmy.tv](https://cani.rootmy.tv) und [webosbrew.org](https://www.webosbrew.org). Für Firmware 2023–2026 funktionierte zum
   Zeitpunkt des Schreibens [throwaway96/slopbro](https://github.com/throwaway96/slopbro).
2. Im Homebrew Channel: **Block system updates** an (ein LG-Update würde Root entfernen), **SSH server** an.
3. Ein Computer mit `ssh`/`scp`. Standardpasswort des Homebrew-SSH-Servers ist `alpine`, ändern oder Schlüssel verwenden.
4. `/usr/bin/node` auf dem TV (ab webOS 5 vorhanden; kopiert die App-Icons).

**Noch nicht gerootet?** Beginne mit [docs/STEP-0-HOMEBREW-SSH.md](docs/STEP-0-HOMEBREW-SSH.md) (Englisch): wo die Root-Methoden dokumentiert sind, Homebrew-Channel-Einstellungen, SSH-Schlüssel, IPK-Installation und die ares-cli-Fallen.

## Installation (10 Minuten)

```bash
# am Computer, aus diesem Repository
scp -r . root@<tv-ip>:/tmp/cleantv
ssh root@<tv-ip> 'sh /tmp/cleantv/tv/install.sh'
```

`install.sh` kopiert Skripte und Konfiguration nach `/var/lib/webosbrew/cleantv`, installiert die zwei Boot-Hooks, schaltet die
LG-Promotionen ab, blockt die Werbe-Hosts für diesen Boot und aktiviert den Launcher **sofort, ohne Neustart und ohne LG-Dienste
neu zu starten**. Home-Taste drücken: der neue Launcher erscheint.

Dann anpassen (alles am TV, als root):

| Was | Wo |
|---|---|
| Hintergrundbild | `/var/lib/webosbrew/cleantv/launcher/wallpaper.jpg` ersetzen (1920×1080 JPEG), zweimal Home drücken |
| Kacheln ausblenden | `config/hidden_apps.txt` bearbeiten, dann `sh /var/lib/webosbrew/cleantv/bin/order.sh` |
| Reihenfolge | `config/order.txt` bearbeiten, dann `order.sh` |
| Store-Preloads bei jedem Boot entfernen | `config/remove_apps.txt` (nur entfernbare Apps) |
| Werbe-Hosts | `config/adblock-hosts` (eine Zeile `0.0.0.0 host`) |
| Aussehen | `launcher/index.html` (reines HTML/CSS/JS, kein Build) |

App-IDs findest du mit `luna-send -n 1 -f luna://com.webos.service.homelaunchpoints/listLaunchPoints '{}'`.

## Rückbau

```bash
ssh root@<tv-ip> 'sh /var/lib/webosbrew/cleantv/bin/rollback-home.sh --permanent'   # LG Home zurück, Hook aus
ssh root@<tv-ip> 'sh /tmp/cleantv/tv/uninstall.sh'                                   # alles aus, Kacheln wieder sichtbar
```

Beides zur Laufzeit, kein Neustart nötig. Die Einstellungsschalter sind LGs eigene Optionen und lassen sich im TV-Menü wieder einschalten.

## Wie es funktioniert (kurz)

- LGs Home (`com.webos.app.home`) ist auf webOS 10/11 eine Flutter-App. Ihr Layout-XML lässt sich per Bind-Mount ersetzen, kann aber weder
  Hintergrundbild noch Uhr. Darum ist der Launcher hier eine **eigene Web-App, die mit LGs Home-App-ID über das Home-Verzeichnis
  gemountet wird**. Sie erbt die Rechte, die Home-Taste öffnet sie, LGs Home zeichnet nie.
- Der App-Manager (SAM) liest `appinfo.json` nur beim Start. Statt SAM neu zu starten (das endet auf dieser Firmware im Schwarzbild,
  siehe Troubleshooting) lässt der Hook SAM **genau dieses eine Manifest neu lesen**: `blockSystemApp` + `releaseBlockSystemApp`.
  Der Trick stammt aus [rorygallagher2024/glasshouse](https://github.com/rorygallagher2024/glasshouse), auch von
  [ecklf/lg-luma](https://github.com/ecklf/lg-luma) genutzt.
- Kacheln werden mit dem offiziellen `homelaunchpoints/hideLaunchPoint` ausgeblendet, die Reihenfolge mit `moveLaunchPoint`. Beides reversibel.
- Icons: Die Web-App darf keine `file://`-Icons aus fremden App-Ordnern laden, darum kopiert `refresh.sh` sie in den Launcher-Ordner.

Details: [docs/HOW-IT-WORKS.md](docs/HOW-IT-WORKS.md). Was schiefging und warum: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md).

## Boot-Verhalten

bootd legt deinen letzten Eingang (z. B. HDMI) bei ~13 s aufs Bild. Homebrew Channel startet seine Hooks bei ~22 s; der Launcher wird bei
~26 s zum Home und automatisch geöffnet. Früher gibt es keinen Eingriffspunkt aus dem Userland, und LGs „Home beim Einschalten“ ist im
Geräteprofil dieses Modells deaktiviert. Die ~13 Sekunden HDMI vor dem Launcher lassen sich darum nicht vermeiden.

## Bewusst nicht enthalten

- Kein IPTV-Anbieter, keine Playlist, keine Zugangsdaten. Für IPTV auf webOS: der quelloffene
  [lennylxx/webos-iptv-player](https://github.com/lennylxx/webos-iptv-player) (Xtream, M3U, EPG, Filme, Serien, Zugangsdaten bleiben auf dem TV).
- Kein Abschalten von Systemdiensten beim Boot (ein `systemctl stop …` aus einem Hook hinterliess diesen TV einmal mit Schwarzbild).
- Kein fremdes Hintergrundbild; Standard ist ein erzeugter Farbverlauf.

## Danksagung

Glasshouse (SAM-Neueinlesen, Home-Takeover), lg-luma (home.sh-Muster), webosbrew.org (Homebrew Channel, init.d-Hooks),
furkan-bayrak/lg-tv-blocklist (Hostliste, Stufe „safe“), throwaway96 (SlopBro).

## Lizenz

MIT. Nutzung auf eigene Gefahr; das verändert einen gerooteten Fernseher.
