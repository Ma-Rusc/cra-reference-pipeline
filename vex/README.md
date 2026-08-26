# VEX-Statements

OpenVEX-Dokumente (Spec v0.2.0), ein Dokument je bewerteter Paketgruppe. Jede
Datei ist ein eigenständiges, gültiges OpenVEX-Dokument — auch mit externem
VEX-Tooling lesbar, nicht nur mit dem `policy`-Job dieses Repos.

| Datei | Paket | Status | Begründung |
|---|---|---|---|
| `perl-base.openvex.json` | `perl-base` (api-python) | `not_affected` | `vulnerable_code_not_in_execute_path` — Perl wird vom Anwendungscode nie aufgerufen |
| `libc6.openvex.json` | `libc6` (api-python) | `affected` | akzeptiertes Restrisiko, je CVE einzeln begründet (kein Fix verfügbar, Angriffspfad im Detail geprüft) |

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
