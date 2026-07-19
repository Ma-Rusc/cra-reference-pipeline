# PLAN.md — Aufbau des CRA-Referenzprojekts (GitHub Free, public)

Reihenfolge ist bewusst gewählt: jede Stufe erzeugt ein Artefakt, das die nächste
braucht. Nach jeder Stufe: Workflow grün, PR, Merge. Kein Big Bang.

---

## Stufe 0 — Fundament, bevor irgendein Code entsteht

Diese Stufe zuerst, weil ein öffentliches Repo ab dem ersten Push öffentlich ist.

- [ ] `.gitignore` (inkl. `.env`, `*.pem`, `*.key`) **vor** dem ersten Commit
- [ ] `.gitleaks.toml` + `.pre-commit-config.yaml`, Hooks installiert
- [ ] SSH-Commit-Signing eingerichtet und verifiziert
- [ ] Repo public anlegen, dann in den Settings:
      Secret Scanning + **Push Protection** an, Dependabot Alerts an
- [ ] Ruleset auf `main`: keine Direct-Pushes, Force-Push und Löschen verboten,
      Status-Checks als Voraussetzung (kommen später dazu)
- [ ] `LICENSE` (Apache-2.0 oder MIT), `README.md` mit dem CRA-Scope-Hinweis
- [ ] `docs/cra/traceability.md` als leere Tabelle
- [ ] `docs/cra/plattform-grenzen.md` anlegen

**Nachweis-Wert:** Ab hier ist jede Änderung signiert, zuordenbar und
nicht rückwirkend manipulierbar. Das ist die Basis des Audit-Trails.

---

## Stufe 1 — Zwei minimale Services + reproduzierbarer Build

- [ ] `services/api-python/` — bewusst trivial, mit Lockfile
- [ ] `services/web-node/` — bewusst trivial, mit `package-lock.json`
- [ ] Je ein Dockerfile, Basis-Image **per Digest** gepinnt
- [ ] `Makefile` mit den Zielen aus CLAUDE.md
- [ ] `.github/workflows/ci.yml`, Job `build` als Matrix über beide Services
- [ ] Push nach GHCR, Image-Digest als Output festhalten
- [ ] Alle Actions per SHA gepinnt

**CRA-Bezug:** Voraussetzung für alles Weitere — ohne eindeutig identifizierbares
Artefakt gibt es nichts zu bescheinigen.

---

## Stufe 2 — SBOM

- [ ] syft gegen den Quellbaum je Service → `sbom/<service>-source.cdx.json`
- [ ] syft gegen das gebaute Image → `sbom/<service>-image.cdx.json`
- [ ] Als Workflow-Artefakt mit bewusst langer Retention
- [ ] Plausibilitätsprüfung: Enthält die SBOM wirklich die transitiven Deps?
      Eine SBOM mit 12 Einträgen bei einem Node-Projekt ist ein Fehler, kein Erfolg.

**CRA-Bezug:** Anhang I Teil II Nr. 1 — Identifikation und Dokumentation der
Komponenten inkl. SBOM in maschinenlesbarem Format. Ohne SBOM lässt sich eine
Meldung ab 09/2026 nicht sauber begründen.

---

## Stufe 3 — Scans, Ergebnisse als SARIF ins Code Scanning

- [ ] grype gegen die SBOM (nicht gegen das Image — die SBOM ist die Quelle)
- [ ] osv-scanner gegen die Lockfiles
- [ ] semgrep gegen `services/`
- [ ] gitleaks gegen Working Tree **und** Historie
- [ ] trivy Lizenz-Scan
- [ ] Alle Ergebnisse als SARIF, Upload mit je eigener `category`
- [ ] `security-events: write` setzen, sonst schlägt der Upload fehl

**CRA-Bezug:** Anhang I Teil II Nr. 3 — regelmäßige Tests auf Schwachstellen.
Teil I Nr. 2 — Auslieferung ohne bekannte ausnutzbare Schwachstellen.

---

## Stufe 4 — Bewertung und Gate (der Teil, den alle unterschätzen)

- [ ] `vex/` mit OpenVEX-Statements, ein File pro bewertete CVE
- [ ] Rego-Policy in `policy/`: Build bricht ab bei Schweregrad ≥ Schwelle,
      **außer** es existiert ein passendes VEX-Statement mit Status und Begründung
- [ ] `conftest` als eigener Gate-Job
- [ ] Bewusst eine echte CVE stehen lassen und durchbewerten — damit man sieht,
      wie der Mechanismus im Ernstfall aussieht
- [ ] VEX-Statements laufen ab. Ein Prozess, der sie regelmäßig überprüft,
      gehört dokumentiert (auch wenn er hier nicht automatisiert ist)

**Warum das der Kern ist:** Eine Pipeline, die bei jedem CVE rot wird, wird nach
zwei Wochen abgeschaltet. Eine, die alles durchwinkt, ist wertlos. Der Nachweis
entsteht erst durch die *dokumentierte Entscheidung*, warum eine Schwachstelle im
eigenen Produkt nicht ausnutzbar ist. Genau danach fragt die Marktüberwachung.

---

## Stufe 5 — Provenance und Verifikation

- [ ] `actions/attest-build-provenance` je Image
      (`permissions: id-token: write, attestations: write, contents: read`)
- [ ] SBOM-Attestation zusätzlich zur Build-Provenance
- [ ] Separater Job, der direkt danach `gh attestation verify` ausführt —
      eine Attestation, die nie geprüft wurde, ist kein Nachweis
- [ ] Verifikationsanleitung ins README, damit Dritte es nachvollziehen können

**CRA-Bezug:** Anhang I Teil II Nr. 7/8 — sichere Verteilung von Updates.
Nutzer müssen prüfen können, dass ein Update wirklich von euch stammt.
Zugleich: unveränderlicher Audit-Trail im öffentlichen Transparency Log.

---

## Stufe 6 — Prozess-Dokumente

- [ ] `SECURITY.md`: CVD-Policy, Meldeweg, Kontakt, Reaktionszeiten
- [ ] `.well-known/security.txt`
- [ ] `SUPPORT.md`: Supportzeitraum und Update-Politik
      (CRA erwartet mindestens 5 Jahre bzw. die erwartete Produktlebensdauer)
- [ ] `.github/dependabot.yml` für beide Ökosysteme + Actions selbst
- [ ] `CHANGELOG.md`, Security-Fixes gesondert gekennzeichnet
- [ ] `.github/workflows/scorecard.yml` (OpenSSF Scorecard)

**CRA-Bezug:** Anhang I Teil II Nr. 4, 5, 6 — Disclosure-Policy, Kontaktstelle,
Veröffentlichung behobener Schwachstellen.

---

## Stufe 7 — Traceability-Matrix (das Dokument, das im Audit zählt)

- [ ] `docs/cra/traceability.md` vollständig füllen:

| CRA-Anforderung | Job | Nachweis | Status |
|---|---|---|---|
| Anhang I Teil II Nr. 1 (SBOM) | `sbom` | `sbom/*.cdx.json` | erfüllt |
| Anhang I Teil II Nr. 3 (Tests) | `scan:*` | SARIF im Code Scanning | erfüllt |
| Anhang I Teil I Nr. 2 (keine bek. Schwachstellen) | `policy` | Gate-Log + VEX | erfüllt |
| Anhang I Teil II Nr. 7 (sichere Updates) | `attest` | Sigstore-Attestation | erfüllt |
| Anhang I Teil I Nr. 3 (sichere Voreinstellungen) | — | Produktdesign | **Lücke** |
| Anhang I Teil I Nr. 9 (Security-Logging) | — | Produktdesign | **Lücke** |
| Vier-Augen-Prinzip | — | organisatorisch | **Lücke (GitHub Free, 1 Person)** |

- [ ] Lücken **stehen lassen und benennen.** Die Pipeline deckt Anhang I Teil II
      (Schwachstellenbehandlung) gut ab und Teil I (Sicherheitseigenschaften) nur
      teilweise — der Rest ist Produktdesign und Organisation. Das ehrlich
      abzubilden ist der eigentliche Wert dieses Referenzprojekts.
- [ ] `docs/cra/plattform-grenzen.md`: was GitHub Free nicht kann, welcher Tier
      es könnte, und was das für den Produktivbetrieb bedeutet

---

## Stufe 8 — Meldepflicht-Trockenübung

- [ ] Issue-Template „Aktiv ausgenutzte Schwachstelle"
- [ ] Runbook: 24h-Frühwarnung → 72h-Vollmeldung → Abschlussbericht
- [ ] Wer meldet, an welches CSIRT (in DE: BSI), über die ENISA Single
      Reporting Platform
- [ ] Trockenübung mit Zeitmessung: von „CVE in der SBOM gefunden" bis
      „Meldetext liegt vor" — wie lange dauert das im eigenen Repo wirklich?

Das ist der Teil, der ab 11.09.2026 scharf ist. Die meisten Organisationen
scheitern dort nicht an der Technik, sondern an der Frage, wer unterschreibt.
