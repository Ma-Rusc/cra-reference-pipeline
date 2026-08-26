# Trade-offs: Basisimage-Wahl je Service

Dokumentiert die Stufe-3.5-Untersuchung (minimale Basisimages gegen die
bestehenden `debian-slim`-Images) und warum die beiden Services am Ende
unterschiedliche Basisimages nutzen, statt einer einheitlichen Antwort.

## Vergleich

Zahlen aus grype-Läufen gegen die jeweilige Image-SBOM (gleiche Methodik
wie im `scan`-Job), Basiswerte vor dieser Umstellung.

| Service | Variante | Startet? | Funde gesamt | High | Critical | `perl-base` dabei? |
|---|---|---|---|---|---|---|
| api-python | `debian-slim` (aktuell, unverändert) | ✅ | 222 | 33 | 7 | ✅ |
| api-python | distroless (`python3-debian12`) | ❌ Crash beim Start | n/a | n/a | n/a | n/a |
| api-python | chainguard (`node` … Analogie `python`) | ❌ Crash beim Start | n/a | n/a | n/a | n/a |
| web-node | `debian-slim` (vor dieser Umstellung) | ✅ | 196 | 28 | 8 | ✅ |
| web-node | distroless (`nodejs22-debian12`) | ✅ | 63 | 24 | 3 | ❌ |
| web-node | **chainguard (`node`) — jetzt umgesetzt** | ✅ | 0 | 0 | 0 | ❌ |

## Warum sich die Wege unterscheiden

Bei `api-python` scheiterten beide Alternativen am Start, beide Male aus
demselben Grund: `pydantic-core`/`uvloop` sind kompilierte CPython-
Extension-Module, deren Binärformat (ABI) an die exakte Python-Minor-Version
gebunden ist, mit der sie gebaut wurden. `distroless/python3-debian12`
bringt Python 3.11 mit, unser Builder nutzt 3.12 — inkompatibel
(`ModuleNotFoundError: No module named 'pydantic_core._pydantic_core'`).
Bei Chainguard driftete im Experiment sogar die Runtime-Version selbst
zwischen `:latest-dev` (Build) und `:latest` (Laufzeit), weil das rollende
Tags ohne garantierte Paarung sind. Ein Wechsel wäre für `api-python` also
kein einfacher Image-Tausch, sondern bräuchte explizites
Python-Versions-Pinning zwischen Build- und Finalstage (z. B. über
`uv python pin` gegen exakt die im Finalimage vorhandene Version) — das ist
hier bewusst **nicht** umgesetzt.

Bei `web-node` gibt es dieses Problem strukturell nicht: Express und seine
Abhängigkeiten sind reines JavaScript ohne native Bindings, daher ist der
Image-Tausch unabhängig von der genauen Node-Patch-Version funktionsfähig.
Deshalb wurde hier auf `chainguard/node` umgestellt (per Digest gepinnt,
nicht `:latest`) — reduziert die grype-Funde auf 0, ohne die im Python-Fall
beobachteten Startprobleme.

## Gegencheck: trivy im Image-Scan-Modus

Die grype-Nullmeldung für `web-node`/chainguard war zunächst nur durch ein
Werkzeug belegt (grype gegen die syft-erzeugte SBOM). Gegengeprüft mit
trivy (gleiche Version wie im `scan`-Job, `0.74.0`) im **Image-Scan-Modus**
(`trivy image --input <tarball>`, nicht `trivy sbom`) gegen exakt dasselbe
digest-gepinnte Image — eine andere Erkennungskette: native Image-
Inspektion statt Vermittlung über eine von syft erzeugte SBOM.

| Tool | Modus | Ziel | Ergebnis |
|---|---|---|---|
| grype | SBOM (`sbom:<datei>`) | syft-erzeugte CycloneDX-SBOM | 0 Funde |
| trivy | Image (`image --input <tarball>`) | dasselbe digest-gepinnte Image direkt | 0 Funde (27 Wolfi-OS-Pakete + Node.js-Sprachziel, beide 0) |

**Einschätzung: Die Null ist robust, kein SBOM-Erfassungsartefakt.** Zwei
Werkzeuge mit unterschiedlicher Erkennungskette (grype+syft über eine
vermittelnde SBOM vs. trivy nativ direkt am Image) kommen zum selben
Ergebnis. Ehrlich dazu: Chainguard-Images sind Wolfi-basiert (apk, nicht
dpkg) und explizit darauf ausgelegt, kontinuierlich neu gebaut und
möglichst CVE-frei gehalten zu werden — die Null bestätigt also auch, dass
dieses Versprechen hier eingehalten wird, ist aber kein Beleg dafür, dass
Wolfi-Pakete grundsätzlich nie Schwachstellen haben werden.
