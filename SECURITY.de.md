# Sicherheitsrichtlinie

> Dieses Dokument ist die deutsche Sicherheitsanleitung. Bei Unklarheiten gilt [`SECURITY.md`](./SECURITY.md) als Hauptreferenz.

## Umfang

Beacon verarbeitet Notfallablaeufe, native Mobile-Bridges und die Verteilung von Offline-Guidance. Bitte melde Schwachstellen verantwortungsvoll.

## Meldung

Bis ein dedizierter Sicherheitskanal eingerichtet ist, nutze nach Moeglichkeit ein privates GitHub Security Advisory. Falls das nicht verfuegbar ist, erstelle ein minimales Issue ohne sensible Exploit-Details und vermerke, dass du einen privaten Folgekanal brauchst.

## Was enthalten sein sollte

- Betroffene Plattform und OS-Version
- Geraetemodell
- Reproduktionsschritte
- Zusammenfassung der Auswirkung
- Ob Offline-Inferenz, native Berechtigungen, Modell-Paketierung oder Wissensauslieferung betroffen sind

## Reaktionsziele

- Eingang so schnell wie moeglich bestaetigen
- Reproduzieren und Schweregrad einschaetzen
- Vor oeffentlicher Detailveroeffentlichung patchen oder abmildern

## Nicht im Umfang

- Allgemeine Diskussionen zur Modellqualitaet ohne konkreten Sicherheits- oder Safety-Fehler
- Reine Upstream-Drittprobleme ohne Beacon-spezifische Auswirkung
