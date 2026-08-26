# CRA-Traceability-Matrix

Ordnet jede abgedeckte CRA-Anforderung einem Job und einem konkreten Nachweis
zu. Lässt sich eine Anforderung nicht sauber abbilden, wird sie als Lücke
markiert — nicht plausibel umformuliert (siehe CLAUDE.md, harte Regel 11).

Wird ab Stufe 7 (siehe [PLAN.md](../../PLAN.md)) befüllt, sobald die
zugehörigen Jobs existieren.

| CRA-Anforderung | Job | Nachweis | Status |
|---|---|---|---|
| Anhang I Teil II Nr. 1 (Komponenten identifizieren, SBOM bereitstellen) | `sbom` | CycloneDX-SBOM je Service, Quelle + Image (`sbom-<service>-source`, `sbom-<service>-image`), 90 Tage Retention | erfüllt |
| Anhang I Teil I Nr. 3 (sichere Voreinstellungen) — Non-Root-Container | — | `USER`-Direktive je Dockerfile, verifiziert mit `docker run --rm <image> id` | Teilweise — Voreinstellung, zur Laufzeit mit `--user root` überschreibbar; deckt nur Non-Root ab, nicht alle Aspekte von "secure by default" |
| Anhang I Teil II Nr. 3 (regelmäßige Tests auf Schwachstellen) | `scan` | SARIF im Code Scanning (grype, osv-scanner, semgrep — je Service, 6 Kategorien) | erfüllt |
| Anhang I Teil I Nr. 2 (keine bekannten ausnutzbaren Schwachstellen bei Auslieferung) | `policy` | conftest-Gate-Log (`$GITHUB_STEP_SUMMARY`) + VEX-Statements (`vex/`) | erfüllt — siehe Einschränkungen unten |

**Einschränkungen (`policy`-Job):**

- **Abdeckung bei api-python vollständig, aber Weg zur Grün-Schaltung
  gemischt.** Von den ursprünglich 26 in Stufe 4 offen gelassenen CVEs
  wurden 17 (python-Interpreter, openssl/openssl-provider-legacy/
  libssl3t64) durch einen Digest-Bump von `python:3.12-slim` gelöst, nicht
  durch VEX — ein verfügbarer Fix schlägt eine Begründung, warum man ihn
  nicht nutzt (siehe Commit-Historie des Folge-PRs). Die verbleibenden 9
  CVEs (`libc-bin`/`libc6`, `ncurses`-Gruppe, `libsqlite3-0`, `libacl1`,
  `gzip`) sind einzeln recherchiert per VEX bewertet
  ([`vex/README.md`](../../vex/README.md)). Zusätzlich wurden bei der
  Recherche 6 der 17 Digest-Bump-Fälle als Scanner-Erfassungsartefakte
  identifiziert (grype meldete sie trotz bereits installierter Fix-Version
  weiter, mit Debian-Tracker/NVD gegengeprüft) — dokumentiert in
  `vex/openssl.openvex.json` und `vex/python-runtime.openvex.json`, nicht
  stillschweigend als "durch den Bump gelöst" verbucht.
- **`policy` ist weiterhin kein erforderlicher Status-Check.** Auch mit
  grünem Gate wurde das Ruleset (`id 19179030`) in diesem PR bewusst nicht
  angefasst — ausdrückliche Vorgabe, das Nachziehen ist ein separater,
  späterer Schritt.
- **Gate matcht Paketname, nicht Version.** `policy/vex_gate.rego` matcht
  VEX-Statements gegen den Paketnamen aus dem grype-Fund, nicht gegen die
  exakte im Statement genannte Paketversion. Ein Statement bleibt damit
  auch nach einem Versionswechsel des Pakets (z. B. ein Debian-
  Sicherheitsupdate für `perl-base`) automatisch gültig — die technische
  Prüfung erzwingt keine Neubewertung bei Versionswechsel, das übernimmt
  ausschließlich der in [`vex/README.md`](../../vex/README.md)
  beschriebene organisatorische Prozess. Bewusste Vereinfachung
  (robusterer Match, weniger Wartungsaufwand), aber auch eine reale Lücke:
  ein technisch unerzwungener Prozess kann unterbleiben.
- **Gate läuft nach dem GHCR-Push, nicht davor.** `build` (inkl. Push nach
  `main`) läuft vor `sbom`/`scan`/`policy`. Ein fehlschlagendes Gate
  verhindert die Auslieferung eines bereits gebauten Images aktuell nicht
  — es liefert eine nachträgliche, sichtbare Bewertung, keine Vorab-Sperre.

**Bekannte Einschränkung (`sbom`-Job):** Die Image-SBOM wird erzeugt, indem
syft im Container das per `docker save` erzeugte OCI-Tarball über einen
Bind-Mount liest und die CycloneDX-Datei in ein ebenfalls gemountetes
Ausgabeverzeichnis zurückschreibt (`sbom/` wird dafür world-writable
gemacht, siehe Kommentar in `ci.yml`). Sauberer wäre eine Variante ganz
ohne Rückschreiben in ein gemountetes Verzeichnis — z. B. Ausgabe auf
stdout und Umleitung erst durch den Runner selbst. Als mögliche spätere
Verbesserung vermerkt, kein funktionaler Mangel — nicht jetzt umgebaut.
