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

### Was ein höherer Tier zusätzlich könnte

Mit GitHub Team/Enterprise: Org-weites Audit-Log, Org-Rulesets, erzwungene
Codeowner-Reviews mit mehreren Personen, SAML/SSO-Pflicht, IP-Allowlisting.
Für ein produktives, mehrköpfiges Team wäre das relevant — für dieses
Referenzprojekt bewusst nicht gewählt.
