# Zu Beacon beitragen

> Dieses Dokument ist die deutsche Beitragsanleitung. Bei Unklarheiten gilt [`CONTRIBUTING.md`](./CONTRIBUTING.md) als Hauptreferenz.

Danke, dass du hilfst, Beacon verlaesslicher zu machen.

## Bevor du eine PR oeffnest

- Pruefe zuerst bestehende Issues, um doppelte Arbeit zu vermeiden.
- Kleine, fokussierte PRs sind besser als sehr breite Refactors.
- Fuege bei UI-Aenderungen Screenshots oder Aufnahmen hinzu.
- Bei Runtime-Bugs gib bitte Geraetemodell, OS-Version und Reproduktionsschritte an.

## Lokales Setup

```bash
npm install
npm test
dart test
```

Wenn du an den mobilen Shells arbeitest:

```bash
npm run mobile:build
```

## Pull-Request-Checkliste

- Aenderungen an Notfallverhalten muessen leicht pruefbar und reviewbar bleiben.
- Fuehre keine Fake-AI-Fallbacks ein.
- Das Offline-First-Verhalten darf nicht durch Netzabhaengigkeit ersetzt werden.
- Wenn du Prompt-Komposition, Session-Memory, Retrieval oder UI-Flow aenderst, aktualisiere auch die Tests.
- Nutzertexte sollen einfach, direkt und fuer Stresssituationen geeignet bleiben.

## Wissensbasis-Beitraege

- Bevorzuge autoritative Quellen aus Medizin, Survival, Wetter und oeffentlicher Sicherheit.
- Beachte fuer jede Quelle Lizenz- und Weiterverteilungsbedingungen.
- Neue Quellen bitte ueber Manifest und Build-Skripte hinzufuegen, nicht durch Handeditieren generierter Bundles.

## Sicherheitsrelevante Aenderungen

Wenn deine Aenderung Signierung, Modell-Paketierung, native Bridges oder sicherheitskritische Guidance betrifft, beschreibe den PR bitte mit mehr Kontext und Validation.
