# VEX-Statements

OpenVEX-Dokumente (Spec v0.2.0), ein Dokument je bewerteter Paketgruppe. Jede
Datei ist ein eigenständiges, gültiges OpenVEX-Dokument — auch mit externem
VEX-Tooling lesbar, nicht nur mit dem `policy`-Job dieses Repos.

| Datei | Paket | Status | Begründung |
|---|---|---|---|
| `perl-base.openvex.json` | `perl-base` (api-python) | `not_affected` | `vulnerable_code_not_in_execute_path` — Perl wird vom Anwendungscode nie aufgerufen |
| `libc6.openvex.json` | `libc6`, `libc-bin` (api-python) | `affected` | akzeptiertes Restrisiko, je CVE einzeln begründet (kein Fix verfügbar, Angriffspfad im Detail geprüft); `libc-bin` als zweites Produkt ergänzt (identisches glibc-Quellpaket, identische Begründung) |
| `openssl.openvex.json` | `openssl`, `openssl-provider-legacy`, `libssl3t64` (api-python) | `not_affected` | teils `vulnerable_code_not_present` (installierte Version laut Debian-Tracker bereits gefixt, grype-Erfassungsartefakt), teils `vulnerable_code_not_in_execute_path` (QUIC-Server/DTLS/CMS — api-python betreibt keines davon) |
| `python-runtime.openvex.json` | `python` (api-python) | `not_affected` | `vulnerable_code_not_present` — NVD nennt "fixed in 3.12.14", installierte Version ist exakt 3.12.14 (grype-Erfassungsartefakt) |
| `ncurses.openvex.json` | `ncurses-bin`, `ncurses-base`, `libtinfo6`, `libncursesw6` (api-python) | `not_affected` | `vulnerable_code_not_in_execute_path` (ncurses-bin: `infocmp`-Binary vorhanden, nie ausgeführt) bzw. `vulnerable_code_not_present` (die drei übrigen Pakete enthalten die verwundbare Funktion laut Debian-Dateiliste gar nicht) |
| `libsqlite3.openvex.json` | `libsqlite3-0` (api-python) | `not_affected` | `vulnerable_code_not_in_execute_path` — Anwendungscode importiert das `sqlite3`-Modul nicht |
| `libacl1.openvex.json` | `libacl1` (api-python) | `not_affected` | `vulnerable_code_not_in_execute_path` — nur über `getfacl`/`setfacl`/`chacl` erreichbar, die der Anwendungscode nie aufruft |
| `gzip.openvex.json` | `gzip` (api-python) | `not_affected` | `vulnerable_code_not_in_execute_path` — externes `gzip`/`gunzip`-Binary wird nie aufgerufen, keine Kompressions-Middleware |

**Nicht per VEX gelöst, sondern per Update:** 17 der ursprünglich 26 in
Stufe 4 offen gelassenen CVEs bei api-python (python-Interpreter,
openssl-Gruppe) hatten `fix.state=fixed` — dafür wurde
`services/api-python/Dockerfile` auf einen neueren `python:3.12-slim`-
Digest gehoben statt eine VEX-Begründung zu schreiben (ein verfügbarer Fix
schlägt eine Begründung, warum man ihn nicht nutzt). Erst danach zeigte
sich per Debian-Tracker-/NVD-Gegenprüfung, dass 6 dieser 17 CVEs
tatsächlich Scanner-Erfassungsartefakte waren (grype meldete sie trotz
bereits installierter Fix-Version weiter) — diese 6 sind trotzdem als
`not_affected`-Statements dokumentiert (`vulnerable_code_not_present`),
nicht stillschweigend weggelassen, weil das Gate sonst bei der nächsten
grype-DB-Aktualisierung erneut ohne Erklärung reagieren würde.

## Wie das Gate diese Dateien nutzt

`policy/vex_gate.rego` matcht Funde aus dem grype-JSON gegen
`vulnerability.name` und den **Paketnamen** aus `products[].@id` (purl) —
nicht gegen die exakte Paketversion im purl. Siehe
[`docs/cra/traceability.md`](../docs/cra/traceability.md) für die
Begründung und die damit verbundene Einschränkung dieses Trade-offs.

## Warum es hier kein Ablaufdatum gibt

OpenVEX (Spec v0.2.0) definiert kein Feld für Ablauf- oder Prüfdatum — nur
`timestamp`/`last_updated` auf Dokument- und Statement-Ebene. Ein
selbst erfundenes `expires`-Feld wäre kein gültiges OpenVEX-Dokument mehr.
Statt eines technischen Ablaufmechanismus gilt deshalb ein **organisatorischer
Prozess**, der hier dokumentiert, aber nicht automatisiert ist:

- **Bei jedem `scan`-Lauf mit neuen CVEs gegen ein bereits bewertetes
  Paket** (gleicher Name, gleiche Version): prüfen, ob die bestehende
  Begründung (`impact_statement`/`status_notes`) auch für die neue CVE
  trägt, und ein neues Statement in der jeweiligen Datei ergänzen — nicht
  automatisch als abgedeckt annehmen. Das Gate selbst matcht nur exakt
  gelistete `vulnerability.name`-Werte; eine neue CVE ohne eigenes
  Statement fällt automatisch durch das Gate (`deny`), das ist beabsichtigt.
- **Bei einem Versionswechsel des Pakets** (z. B. ein Debian-
  Sicherheitsupdate für `perl-base` oder `libc6`): das Statement muss neu
  bewertet werden, auch wenn der Paketname gleich bleibt. Der
  paketnamen-basierte Match im Gate erzwingt das technisch **nicht** — eine
  neue Version wird ohne manuelles Eingreifen weiterhin durch das
  bestehende Statement gedeckt. Das ist eine bewusste Vereinfachung (siehe
  `traceability.md`), keine automatische Absicherung.
- **`version`** im Dokument-Header wird bei jeder inhaltlichen Änderung
  erhöht, **`timestamp`**/`last_updated` aktualisiert — damit lässt sich in
  der Git-Historie nachvollziehen, wann zuletzt bewertet wurde.

Kein automatisierter Reminder ist eingerichtet (das wäre über den Umfang
dieses Referenzprojekts hinaus) — die nächste Gelegenheit, den Prozess
tatsächlich anzuwenden, ist der für Stufe 4 bereits angekündigte Folge-PR,
der die restlichen unbewerteten Pakete durchgeht.

## Verifikation (Stufe 4)

Zwei Eigenschaften des Gates wurden nicht nur behauptet, sondern live in
CI beobachtet:

**(1) Baustein-3-Fehlerinjektion — der Schutz gegen stillen Fehlschlag
greift wirklich.** `vex/perl-base.openvex.json` wurde in einem eigenen
Commit absichtlich auf ein leeres `{"statements": []}` reduziert und
gepusht. Ergebnis in
[Run 32948581758](https://github.com/Ma-Rusc/cra-reference-pipeline/actions/runs/32948581758):
beide Matrix-Legs (`policy (api-python)` und `policy (web-node)`) brachen
mit `::error::vex/perl-base.openvex.json ist kein valides OpenVEX-Dokument
(fehlendes/leeres statements-Array)` ab — eine leere/kaputte VEX-Datei
wurde nicht stillschweigend als "keine Einschränkungen" durchgereicht.
Der Testcommit wurde anschließend per `git revert` zurückgenommen (beide
Commits bleiben in der Historie sichtbar, kein Force-Push).

**(2) Trennschärfe des paketnamen-basierten Matches — keine Überdeckung.**
Der Match in `policy/vex_gate.rego` vergleicht Paketnamen, nicht exakte
purls (siehe oben) — das birgt grundsätzlich ein Überdeckungsrisiko, falls
zwei VEX-Dateien versehentlich denselben oder einen zu unscharf erkannten
Paketnamen abdecken. In
[Run 32950302143](https://github.com/Ma-Rusc/cra-reference-pipeline/actions/runs/32950302143)
erzeugte das Gate für api-python genau 15 `warn`-Meldungen (12 für
`perl-base`, 3 für `libc6`) und keine einzige davon für ein anderes Paket
— lokal mit den echten Job-Daten (identische grype-JSON- und
VEX-Combined-Eingabe) nachgerechnet und mit dem tatsächlichen
conftest-Exit-Code des Laufs abgeglichen. Kein `deny` wegen
"mehrdeutige VEX-Abdeckung" trat auf. Für die aktuellen Paketnamen ist der
Match damit nachweislich präzise — das bleibt eine laufende Eigenschaft,
die bei jeder neuen VEX-Datei erneut gilt, nicht ein einmalig bewiesenes
Faktum.

**(3) Folge-PR: `policy (api-python)` grün, weiterhin keine
Überdeckung.** Nach Digest-Bump (python-Interpreter, openssl-Gruppe) und
sechs neuen VEX-Dateien für die restlichen Pakete ist
[Run 32969123841](https://github.com/Ma-Rusc/cra-reference-pipeline/actions/runs/32969123841)
für beide Services grün — auch `policy (api-python)` läuft jetzt
erfolgreich durch. Lokal mit dem grype-JSON-Artefakt dieses Laufs
nachgerechnet: 51 `warn`-Meldungen, 0 `deny`, jede davon mit genau einem
passenden Statement (keine Mehrdeutigkeit trotz deutlich größerer
Statement-Menge). Aufschlüsselung nach Quelldokument:

| Quelldokument | warn-Meldungen |
|---|---|
| `vex/perl-base.openvex.json` | 12 |
| `vex/libc6.openvex.json` | 6 (3 CVEs × je 2 Produkte: `libc6`, `libc-bin`) |
| `vex/openssl.openvex.json` | 21 (7 CVEs × je 3 Produkte: `openssl`, `openssl-provider-legacy`, `libssl3t64`) |
| `vex/python-runtime.openvex.json` | 3 |
| `vex/ncurses.openvex.json` | 4 (1 CVE × 4 Pakete, über zwei Statements mit unterschiedlicher Begründung) |
| `vex/libsqlite3.openvex.json` | 2 |
| `vex/libacl1.openvex.json` | 2 |
| `vex/gzip.openvex.json` | 1 |

Jede Zeile in dieser Tabelle ist gegen das tatsächliche
`_source_document`-Feld der lokal nachgerechneten `warn`-Liste geprüft,
nicht geschätzt.
