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

**Bekannte Einschränkung (`sbom`-Job):** Die Image-SBOM wird erzeugt, indem
syft im Container das per `docker save` erzeugte OCI-Tarball über einen
Bind-Mount liest und die CycloneDX-Datei in ein ebenfalls gemountetes
Ausgabeverzeichnis zurückschreibt (`sbom/` wird dafür world-writable
gemacht, siehe Kommentar in `ci.yml`). Sauberer wäre eine Variante ganz
ohne Rückschreiben in ein gemountetes Verzeichnis — z. B. Ausgabe auf
stdout und Umleitung erst durch den Runner selbst. Als mögliche spätere
Verbesserung vermerkt, kein funktionaler Mangel — nicht jetzt umgebaut.
