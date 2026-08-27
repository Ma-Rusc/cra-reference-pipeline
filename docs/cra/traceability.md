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
| Anhang I Teil II Nr. 7/8 (sichere Verteilung von Updates, Herkunft nachprüfbar) | `push` | Sigstore-Attestation (Build-Provenance + SBOM, `actions/attest-build-provenance` + `actions/attest`) je Image-Digest, verifiziert im selben Job per `gh attestation verify` (zwei Aufrufe, Provenance- und SBOM-Prädikattyp getrennt) | erfüllt — siehe Beleg und Einschränkungen unten |

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

**Beleg (Attestation, Stufe 5 Abschluss).** [Run 33057376219](https://github.com/Ma-Rusc/cra-reference-pipeline/actions/runs/33057376219)
(`push (api-python)`, `push (web-node)`: beide `success`) zeigt im Log für
beide Attestationen `Attestation signature uploaded to Rekor transparency
log` sowie die Attestation-URLs
[.../attestations/43352837](https://github.com/Ma-Rusc/cra-reference-pipeline/attestations/43352837)
(Provenance) und
[.../attestations/43352863](https://github.com/Ma-Rusc/cra-reference-pipeline/attestations/43352863)
(SBOM). Zusätzlich unabhängig gegen die öffentliche Rekor-API geprüft
(`curl https://rekor.sigstore.dev/api/v1/log/entries?logIndex=...`, nicht
nur behauptet): Log-Index `2615418281` (Provenance) und `2615418580`
(SBOM) existieren als valide DSSE-Einträge, ihre `integratedTime`
(09:16:14 UTC bzw. 09:16:19 UTC) liegt exakt im Ausführungsfenster von
`push (api-python)` in diesem Run und in der richtigen Reihenfolge
(Provenance vor SBOM). **Was diese Prüfung nicht abdeckt:** Sie bestätigt
Existenz, Zeitpunkt und Reihenfolge der beiden Log-Einträge — nicht die
Bindung an den konkreten Image-Digest/Payload-Inhalt. Dafür wäre eine
vollständige Signaturverifikation nötig (z. B. via `cosign`), nicht nur
ein Abruf der Rekor-API. Diese Lücke ist Teil des Nachweiswerts und wird
hier bewusst nicht verschwiegen. Ergänzend: externe Verifikation per
`gh attestation verify --repo Ma-Rusc/cra-reference-pipeline` von einer
Maschine außerhalb der Pipeline, beide Prädikattypen erfolgreich.

**Negativtest (Stufe 5 Abschluss): belegt, nicht mehr offen.** Der
Positivfall ist durch [Run 33051921487](https://github.com/Ma-Rusc/cra-reference-pipeline/actions/runs/33051921487)
belegt (`push (api-python)`/`push (web-node)` erfolgreich nach grünem
Gate). Der Negativfall — ein rotes `policy` verhindert den Merge/Push
tatsächlich — wurde durch einen eigenen, bewusst nicht gemergten
Test-PR ([#17](https://github.com/Ma-Rusc/cra-reference-pipeline/pull/17),
Branch inzwischen gelöscht, PR und Run-Link bleiben über
`refs/pull/17/head` erhalten) geprüft: `vex/perl-base.openvex.json`
wurde entfernt (nicht nur geleert — das testet den echten `deny`-Pfad
des Gates bei fehlender VEX-Abdeckung, nicht die bereits in Stufe 4
bewiesene Dateivalidierung). In
[Run 33072727678](https://github.com/Ma-Rusc/cra-reference-pipeline/actions/runs/33072727678)
liefen die Validierungs- und Merge-Schritte des `policy`-Jobs erfolgreich
durch, erst der eigentliche `conftest`-Lauf schlug fehl (`policy
(api-python)`: `failure`) — Beleg (a). Für Beleg (b) wurde die
PR-Mergeability direkt abgefragt (`gh pr view 17 --json
mergeable,mergeStateStatus`), nicht angenommen: `mergeStateStatus:
BLOCKED` bei `mergeable: MERGEABLE` — der PR war durch den fehlenden
erforderlichen Status-Check `policy (api-python)` blockiert, nicht durch
einen Konflikt. Beide Mechanismen greifen damit unabhängig voneinander,
wie behauptet. PR #17 wurde anschließend ohne Merge geschlossen.

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
