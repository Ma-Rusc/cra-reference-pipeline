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

## Attestation selbst prüfen

Jedes nach `main` gepushte Image wird mit zwei Sigstore-Attestationen
versehen — Build-Provenance (welcher Workflow in welchem Repo hat es
gebaut) und die zugehörige SBOM —, gebunden an den Registry-Digest, nicht
an den veränderlichen Tag. Der Wert dieser Attestationen liegt darin,
dass Dritte sie selbst prüfen können, ohne diesem Repository oder seinem
Betreiber zu vertrauen: die kryptografische Kette läuft über die
öffentliche Sigstore-Infrastruktur (Fulcio als Zertifizierungsstelle für
die kurzlebige, an die GitHub-Actions-OIDC-Identität gebundene Signatur,
Rekor als unveränderliches Transparenzprotokoll). Mit installiertem
[GitHub CLI](https://cli.github.com/):

```bash
# Build-Provenance
gh attestation verify oci://ghcr.io/ma-rusc/api-python@<digest> \
  --repo Ma-Rusc/cra-reference-pipeline

# SBOM (CycloneDX)
gh attestation verify oci://ghcr.io/ma-rusc/api-python@<digest> \
  --repo Ma-Rusc/cra-reference-pipeline \
  --predicate-type https://cyclonedx.org/bom
```

Zwei getrennte Aufrufe, weil zwei unterschiedliche Prädikattypen bezeugt
werden — ein einzelner Aufruf würde per Default nur die Build-Provenance
(SLSA Provenance v1) prüfen, nicht die SBOM. `--repo` statt `--owner`:
bindet die Identitätsprüfung an genau dieses Repository, nicht an
sämtliche Repositories des Accounts — die präzisere der beiden von `gh`
angebotenen Optionen. `<digest>` ist der `sha256:...`-Digest aus dem
Step-Summary des jeweiligen `push`-Jobs (Actions-Lauf des betreffenden
Commits).
