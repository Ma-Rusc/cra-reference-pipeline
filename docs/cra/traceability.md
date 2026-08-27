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
| Anhang I Teil II Nr. 7/8 (sichere Verteilung von Updates, Herkunft nachprüfbar) | `push` | Sigstore-Attestation (Build-Provenance + SBOM, `actions/attest-build-provenance` + `actions/attest`) je Image-Digest, verifiziert im selben Job per `gh attestation verify` (zwei Aufrufe, Provenance- und SBOM-Prädikattyp getrennt) | Teilweise — Mechanismus verdrahtet, aber im PR-Lauf nicht beobachtbar (`push` läuft nur bei Push nach `main`); erst nach einem echten Post-Merge-Lauf mit grünem Ergebnis auf "erfüllt" hochstufen. Siehe Einschränkungen unten |

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

**Korrektur (Stufe 5): "erfüllt" war vor diesem Schritt nicht zutreffend.**
Bis Stufe 5 lief der GHCR-Push im `build`-Job, *bevor* `sbom`/`scan`/
`policy` liefen — ein rotes Gate hätte die Auslieferung eines bereits
gepushten Images nicht verhindert, das war eine nachträgliche Bewertung,
keine Vorab-Sperre. Die frühere "erfüllt"-Zeile war damit zum Zeitpunkt
ihres Schreibens sachlich unzutreffend, nicht nur unvollständig
dokumentiert. Erst mit Stufe 5 wird die Anforderung technisch
durchgesetzt: `push` (der Job, der tatsächlich nach GHCR veröffentlicht)
läuft jetzt mit `needs: [sbom, scan, policy]` und nur bei Push nach
`main`; `policy (api-python)` und `policy (web-node)` sind zusätzlich
erzwungene Status-Checks im Ruleset (`id 19179030`, gegen `gh api`
verifiziert, in diesem Schritt nicht verändert) — ein rotes Gate
blockiert den Push jetzt technisch, nicht nur sichtbar im Nachhinein.
Der `push`-Job verifiziert zusätzlich über die Docker-Image-ID, dass
exakt das geprüfte und kein neu gebautes Image veröffentlicht wird. Erst
ab diesem Stand ist "erfüllt" ehrlich.

**Offener Negativtest.** Der Positivfall ist durch einen echten Lauf
belegt: [Run 33051921487](https://github.com/Ma-Rusc/cra-reference-pipeline/actions/runs/33051921487)
(erster `push`-Event-Lauf nach dem Merge der Push-Reihenfolge-Änderung)
zeigt `push (api-python)` und `push (web-node)` erfolgreich, nachdem
`sbom`/`scan`/`policy` grün liefen. Der Negativfall — ein rotes `policy`
verhindert den Push tatsächlich — ist verdrahtet (`needs: [sbom, scan,
policy]`), aber durch **keinen** Testlauf belegt, anders als die
Baustein-3-Fehlerinjektion für das `policy`-Gate selbst in Stufe 4
([vex/README.md](../../vex/README.md)). Das ist eine offene Lücke, keine
Erfüllung — bewusst nicht in diesem Schritt nachgeholt (Umfang: Push-
Reihenfolge und Attestation, kein weiterer Fehlerinjektionstest).

**Einschränkungen (`push`-Job, Attestation):**

- **Registry-Speicherung, nicht nur GitHub-Speicherung.** Beide
  Attestationen werden mit `push-to-registry: true` erzeugt — zusätzlich
  zur GitHub-Attestations-API auch als OCI-Referrer in der Registry
  selbst auffindbar, damit auch registry-native Werkzeuge (cosign, oras)
  sie ohne GitHub-API finden. Der eigentliche Vertrauensanker bleibt in
  beiden Fällen Sigstore (Fulcio/Rekor), nicht GitHub selbst.
- **Verifikation läuft im selben Job, der auch pusht.** `gh attestation
  verify` läuft direkt im Anschluss an das Attestieren, nicht als
  unabhängiger, später ausgelöster Job. Für dieses Referenzprojekt
  bewusst so gewählt (einfacher, gleicher Kontext), schwächer als eine
  komplett getrennte, zeitversetzte Nachprüfung.
- **Zwei `gh attestation verify`-Aufrufe statt einem**, weil Build-
  Provenance (SLSA Provenance v1) und SBOM (CycloneDX,
  `https://cyclonedx.org/bom`) unterschiedliche Prädikattypen sind und
  `gh attestation verify` per Default nur den ersten erzwingt. Wird eine
  dritte Attestationsart ergänzt, muss das hier und im README-
  Verifikationsbeispiel mitgepflegt werden — kein automatischer
  Gleichlauf.

**Bekannte Einschränkung (`sbom`-Job):** Die Image-SBOM wird erzeugt, indem
syft im Container das per `docker save` erzeugte OCI-Tarball über einen
Bind-Mount liest und die CycloneDX-Datei in ein ebenfalls gemountetes
Ausgabeverzeichnis zurückschreibt (`sbom/` wird dafür world-writable
gemacht, siehe Kommentar in `ci.yml`). Sauberer wäre eine Variante ganz
ohne Rückschreiben in ein gemountetes Verzeichnis — z. B. Ausgabe auf
stdout und Umleitung erst durch den Runner selbst. Als mögliche spätere
Verbesserung vermerkt, kein funktionaler Mangel — nicht jetzt umgebaut.
