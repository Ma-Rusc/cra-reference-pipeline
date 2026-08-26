# Plattform-Grenzen: GitHub Free, öffentliches Repo, eine Person

Dieses Dokument hält fest, was die gewählte Plattform-Konfiguration nicht
leisten kann — und dass diese Grenzen bewusst dokumentiert statt umgangen oder
beschönigt werden (siehe CLAUDE.md, Abschnitt "Plattform-Rahmen").

## Warum GitHub Free, public, ein Account

Public ist Voraussetzung dafür, dass auf Free kostenlos funktionieren:
Rulesets, Code Scanning / SARIF-Upload, Artifact Attestations, unbegrenzte
Actions-Minuten, kostenloses GHCR. Ein Team- oder Enterprise-Plan würde mehr
Governance-Funktionen freischalten, ist für ein Referenzprojekt aber nicht
gerechtfertigt.

## Konkrete Grenzen

### Kein erzwingbares Vier-Augen-Prinzip

Mit einer einzigen Person im Repo lässt sich keine Regel konfigurieren, die
eine zweite, unabhängige Person zur Freigabe zwingt. Das Ruleset auf `main`
hat deshalb bewusst `required_approving_review_count: 0` und
`require_code_owner_review: false` (keine CODEOWNERS-Datei, kein zweiter
Account). Diese Lücke wird in der Traceability-Matrix
([traceability.md](traceability.md)) explizit als "Lücke (GitHub Free, 1
Person)" geführt, nicht stillschweigend als erfüllt markiert.

### Kein Org-Audit-Log, keine Org-weiten Rulesets

Ohne GitHub Team/Enterprise gibt es kein zentrales Audit-Log über alle
Repo-Settings-Änderungen und keine Möglichkeit, Rulesets auf Organisationsebene
zu erzwingen. Repo-Settings-Änderungen sind nur über die (kürzere)
Repo-Ereignis-Historie und `gh api` nachvollziehbar, nicht über ein
vollständiges Audit-Log.

### Ruleset-Bypass als bewusste Abweichung

Das Ruleset `main` (id 19179030) wurde ursprünglich mit
`bypass_actors: []` und `current_user_can_bypass: never` angelegt. Bei einer
Single-Person-Repo bedeutet das im Fehlerfall (z. B. eine Regel blockiert
fälschlich, obwohl der Inhalt korrekt ist): Der einzige Account kann sich
selbst nicht mehr freischalten. Deshalb wurde der Repo-Owner in Stufe 0 als
Bypass-Actor ergänzt. Das ist eine bewusste Abweichung von "kein Bypass" —
Begründung: ein Aussperr-Risiko ohne zweite Person ist ein größeres
praktisches Risiko als ein theoretisch möglicher, aber durch Commit-Signing
und Push Protection ohnehin nachvollziehbarer Bypass durch den Owner selbst.

### CodeQL-Regel im Ruleset ohne (noch) laufenden Workflow

Das Ruleset enthält eine `code_scanning`-Regel (CodeQL,
`security_alerts_threshold: high_or_higher`), obwohl noch kein
CodeQL-Workflow existiert (kommt erst mit Stufe 1/3). Ob das erste PRs
blockiert, wird beobachtet und hier nachgetragen, sobald es sich zeigt —
nicht im Voraus als gelöst behauptet.

### Lokales `docker run` vs. CI-Runner

Im lokalen Agenten-Arbeitsumfeld ist `docker run` als Sicherheitsgrenze der
Betriebsumgebung gesperrt — schützt die Arbeitsmaschine der Entwicklerin
davor, dass ein Agent beliebige Container ausführt. Das ist keine
Repo-Einstellung, sondern eine Grenze der lokalen Session; genau deswegen
musste die Stufe-3.5-Minimal-Image-Untersuchung
([trade-offs.md](trade-offs.md)) von "lokal bauen und starten" auf
"über die Pipeline verifizieren" umgestellt werden.

Der GitHub-Actions-Runner ist dagegen eine vollständig isolierte, nach
jedem Job weggeworfene Einweg-VM — eine andere Vertrauensgrenze. Deshalb
dürfen dort `docker run`-basierte Schritte (syft, grype, gitleaks, der
Smoke-Test im `build`-Job) frei laufen, ohne dass das ein Widerspruch zur
lokalen Sperre wäre: Was auf der eigenen Arbeitsmaschine ein Risiko ist
(unkontrollierte Ausführung, persistente Seiteneffekte), ist auf einer
Wegwerf-VM ohne Anschluss an die lokale Umgebung keins.

Das erlaubt einen breiten Bind-Mount (`-v "$PWD:/work"`), macht ihn aber
nicht automatisch die richtige Wahl. Ab Stufe 4 (Policy-Gate) bekommen neue
`docker run`-Aufrufe möglichst enge, wo sinnvoll read-only Mounts — die
zweite grype-Ausgabe im `scan`-Job mountet nur die SBOM-Datei (`:ro`) und
`reports/`, der `conftest`-Aufruf im `policy`-Job mountet `policy/` und
`reports/` beide `:ro`, da conftest nichts schreibt. Ehrlich dazu: die
bereits bestehenden Stufe-3-Schritte (SARIF-Erzeugung mit grype, osv-scanner,
semgrep, trivy) laufen weiterhin mit dem breiteren `-v "$PWD:/work"`-Mount —
das rückwirkend zu verengen ist kein Sicherheitsgewinn ohne echten
Bedrohungsvermittler (Wegwerf-VM, siehe oben) und war nicht Teil dieser
Änderung, wird hier aber nicht verschwiegen.

### `policy`-Job endet für api-python absichtlich rot (Abweichung von Regel 12)

CLAUDE.md, harte Regel 12: "Ein Job pro PR. Inkrementell aufbauen, jeder Job
wird grün gesehen, bevor der nächste entsteht." Der `policy`-Job aus Stufe 4
verletzt das für `policy (api-python)` bewusst: nur die Paketgruppen
`perl-base` und `libc6` sind bewertet (siehe
[traceability.md](traceability.md)), rund 15 weitere Pakete mit
high/critical-Funden sind es nicht — das Gate bricht deshalb korrekt ab statt
grün durchzulaufen.

Begründung, warum das hier keine stillschweigende Regelverletzung ist,
sondern eine bewusste Abweichung: PLAN.md fordert für Stufe 4 ausdrücklich,
"bewusst eine echte CVE stehen zu lassen und durchzubewerten — damit man
sieht, wie der Mechanismus im Ernstfall aussieht". Ein Gate, das beim ersten
Lauf grün ist, hätte diesen Fall nie gezeigt. Die Konsequenz wird begrenzt,
nicht verschwiegen: `policy` ist deshalb bewusst **kein** erforderlicher
Status-Check im Ruleset (`id 19179030`) — ein rotes, nicht erzwungenes Gate
sperrt `main` nicht. Erst nach einem Folge-PR, der die restlichen Pakete
bewertet, wird `policy` zum Ruleset ergänzt und Regel 12 wieder eingehalten.

### Was ein höherer Tier zusätzlich könnte

Mit GitHub Team/Enterprise: Org-weites Audit-Log, Org-Rulesets, erzwungene
Codeowner-Reviews mit mehreren Personen, SAML/SSO-Pflicht, IP-Allowlisting.
Für ein produktives, mehrköpfiges Team wäre das relevant — für dieses
Referenzprojekt bewusst nicht gewählt.
