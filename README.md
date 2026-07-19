# cra-reference-pipeline

Referenz-Repository: zwei kleine Beispielprodukte (Python-Service, Node-Service),
ausgeliefert als Container-Images, mit einer GitHub-Actions-Pipeline aus
Open-Source-Werkzeugen, die die **Nachweise** erzeugt, die eine
CRA-Konformitätsbewertung braucht.

Die Pipeline macht ein Produkt nicht CRA-konform. Sie erzeugt Artefakte und
einen Audit-Trail. Die Konformitätsbewertung selbst ist ein organisatorischer
Prozess.

Nicht-Ziel: Produktionsreife. Ziel: Nachvollziehbarkeit und Lesbarkeit.

## CRA-Scope-Hinweis

Dieses Repository ist selbst kostenlose Open-Source-Software ohne
Gewinnerzielungsabsicht und fällt damit nicht in den Anwendungsbereich des
Cyber Resilience Act (CRA). Es demonstriert die Pipeline, es ist kein
CRA-pflichtiges Produkt.

## Aufbau

Der Aufbau erfolgt schrittweise, siehe [PLAN.md](PLAN.md). Aktueller Stand
und CRA-Anforderungs-Zuordnung: [docs/cra/traceability.md](docs/cra/traceability.md).
Grenzen der Plattform (GitHub Free, öffentliches Repo, eine Person):
[docs/cra/plattform-grenzen.md](docs/cra/plattform-grenzen.md).

Details zu Stack, Werkzeugen und harten Regeln: [CLAUDE.md](CLAUDE.md).
