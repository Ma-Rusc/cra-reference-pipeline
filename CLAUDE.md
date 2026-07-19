# CLAUDE.md

## Was dieses Projekt ist

Referenz-Repository: zwei kleine Beispielprodukte (Python-Service, Node-Service),
ausgeliefert als Container-Images, mit einer GitHub-Actions-Pipeline aus
Open-Source-Werkzeugen, die die **Nachweise** erzeugt, die eine
CRA-Konformitätsbewertung braucht.

Die Pipeline macht ein Produkt nicht CRA-konform. Sie erzeugt Artefakte und einen
Audit-Trail. Die Konformitätsbewertung selbst ist ein organisatorischer Prozess.

Nicht-Ziel: Produktionsreife. Ziel: Nachvollziehbarkeit und Lesbarkeit.

Hinweis fürs README: Dieses Repo ist selbst kostenlose Open-Source-Software ohne
Gewinnerzielungsabsicht und fällt damit nicht in den Anwendungsbereich des CRA.
Es demonstriert die Pipeline, es ist kein CRA-pflichtiges Produkt.

## Plattform-Rahmen (bestimmt sehr viel!)

- **GitHub Free, persönlicher Account, Repository PUBLIC**
- Public ist die Voraussetzung dafür, dass auf Free funktionieren:
  Rulesets, Code Scanning / SARIF-Upload, Artifact Attestations,
  unbegrenzte Actions-Minuten, kostenloses GHCR
- **Kein** GitHub Team/Enterprise → kein Org-Audit-Log, keine Org-weiten Rulesets,
  keine erzwungenen Approvals mit nur einer Person
- Diese Grenzen werden dokumentiert, nicht umgangen und nicht beschönigt
- Alle Scanner laufen ausschließlich in GitHub Actions. Lokal sind nur git, gh, docker, pre-commit und claude vorhanden. Keine Make-Targets bauen, die lokal installierte Scanner voraussetzen.

## Stack

- `services/api-python/` — Python 3.12, uv, Container
- `services/web-node/`   — Node 22, npm mit Lockfile, Container
- Registry: GHCR (ghcr.io)
- CI: GitHub Actions, Matrix über beide Services

## Werkzeuge (Open Source, alle per SHA gepinnt)

| Zweck | Tool |
|---|---|
| SBOM (CycloneDX) | syft |
| Schwachstellen Deps + Image | grype, trivy |
| Schwachstellen Ökosystem | osv-scanner |
| SAST | semgrep |
| Secrets | gitleaks |
| Lizenzen | trivy license |
| Provenance / Signatur | actions/attest-build-provenance (Sigstore) |
| Verifikation | gh attestation verify |
| Ausnutzbarkeit | OpenVEX |
| Policy-Gates | conftest / OPA |
| Repo-Hygiene | OpenSSF Scorecard |
| Dependency-Updates | Dependabot |

## Harte Regeln

### Secrets — oberste Priorität, das Repo ist öffentlich

1. **Niemals** ein Kennwort, API-Key, Token, Zertifikat oder eine echte interne
   URL/Adresse in Code, Config, Testdaten, Kommentar oder Commit-Message
   schreiben. Auch nicht "nur zum Testen", auch nicht als Platzhalter, der echt
   aussieht.
2. Platzhalter immer eindeutig unecht: `REPLACE_ME`, `sk-example-not-a-real-key`.
3. Alle Geheimnisse in GitHub Actions Secrets bzw. lokal in `.env` (gitignored).
   `.env.example` mit leeren Werten wird committet.
4. Vor **jedem** Commit läuft gitleaks. Pre-Commit-Hook ist Pflicht, nicht optional.
5. Secret Scanning **Push Protection** im Repo aktivieren (auf public kostenlos).
6. Wird doch etwas geleakt: Der Key ist ab dann kompromittiert. Rotieren, nicht
   nur den Commit löschen. Git-Historie umschreiben allein reicht nie.

### Nachweise

7. **Alles per SHA pinnen** — Actions (`uses: owner/action@<sha>`), Basis-Images
   per Digest, Tool-Versionen fix. Ein `@v4` oder `:latest` zerstört die
   Reproduzierbarkeit und damit den Nachweiswert.
8. **Kein Artefakt ohne SBOM.** Pro Service je eine SBOM für Quellcode und Image.
9. **Keine CVE wird stillschweigend ignoriert.** Akzeptierte Findings brauchen ein
   OpenVEX-Statement in `vex/` mit Status und Begründung. Kein `--ignore-unfixed`
   ohne VEX-Eintrag.
10. **Signierte Commits** (SSH-Signing), auch die von Claude.
11. **Nichts erfinden.** Lässt sich eine CRA-Anforderung nicht sauber auf einen Job
    abbilden, wird sie in `docs/cra/traceability.md` als Lücke markiert — nicht
    plausibel umformuliert. Eine falsche Zuordnung ist schlimmer als eine Lücke.
12. **Ein Job pro PR.** Inkrementell aufbauen, jeder Job wird grün gesehen,
    bevor der nächste entsteht.

## Befehle

```bash
# lokal
make lint test
make sbom              # syft -> sbom/
make scan              # grype, osv-scanner, semgrep, gitleaks, trivy
make policy            # conftest gegen scan-Ergebnisse + vex/
make secrets-check     # gitleaks über Working Tree UND Historie

# GitHub (Debugging-Schleife!)
gh workflow list
gh run watch
gh run view --log-failed        # <- der wichtigste Befehl beim Debuggen
gh pr create --fill
gh attestation verify oci://ghcr.io/OWNER/IMAGE --owner OWNER
```

## Repo-Struktur

```
.github/workflows/
  ci.yml                 # build, sbom, scan, policy, attest
  scorecard.yml          # OpenSSF Scorecard
.github/dependabot.yml
services/
  api-python/
  web-node/
policy/                  # Rego-Regeln für die Gates
vex/                     # OpenVEX-Statements
docs/cra/
  traceability.md        # CRA-Anforderung -> Job -> Nachweis (Kerndokument)
  plattform-grenzen.md   # was GitHub Free nicht kann und warum
SECURITY.md              # Coordinated Vulnerability Disclosure
SUPPORT.md               # Supportzeitraum, Update-Politik
.well-known/security.txt
.gitleaks.toml
.pre-commit-config.yaml
```

## Definition of Done für einen Job

- Läuft in GitHub Actions grün (nicht nur lokal)
- Erzeugt ein benanntes Artefakt mit bewusst gesetzter Retention
- Ist in `docs/cra/traceability.md` genau einer CRA-Anforderung zugeordnet
- Action und Tool per SHA gepinnt
- Fehlerverhalten definiert: bricht ab oder warnt — und begründet warum

## Fallstricke

- `permissions:` im Workflow explizit und minimal setzen. Der Default ist zu weit.
- Attestations brauchen `id-token: write`, `attestations: write`, `contents: read`.
  Häufigste Fehlerquelle beim ersten Versuch.
- SARIF-Upload braucht `security-events: write`.
- Mehrere SARIF-Uploads pro Commit brauchen je eine eigene `category`,
  sonst überschreiben sie sich gegenseitig.
- Artefakt-Retention: Nachweise dürfen nicht nach 90 Tagen verschwinden.
- SBOM des Images != SBOM der Anwendung. Beide erzeugen, beide behalten.
- Zwei Services = Matrix. Nicht zwei kopierte Workflows pflegen.
- Workflows aus einem PR eines Forks laufen mit eingeschränkten Rechten.
Relevant, sobald das Repo public ist und jemand einen PR stellt.
