package main

# Eingabe: grype-JSON (input.matches[]), siehe vex/README.md für das
# Zusammenspiel mit den VEX-Statements (data.statements[], zusammengeführt
# aus vex/*.json durch den policy-Job in ci.yml, je Statement ergänzt um
# _source_document).

severity_threshold := {"high", "critical"}

is_gated(severity) {
    severity_threshold[lower(severity)]
}

# Paketname aus einem OpenVEX-Produkt-purl extrahieren, z. B.
# "pkg:deb/debian/perl-base@5.40.1-6?arch=amd64..." -> "perl-base".
package_name(purl) = name {
    segments := split(purl, "/")
    last_segment := segments[count(segments) - 1]
    name_and_rest := split(last_segment, "@")
    name := name_and_rest[0]
}

covering_statements(m) = statements {
    statements := [s |
        s := data.statements[_]
        s.vulnerability.name == m.vulnerability.id
        product := s.products[_]
        package_name(product["@id"]) == m.artifact.name
    ]
}

# Kein VEX-Statement für einen gegateten Fund -> Build bricht ab.
deny[msg] {
    m := input.matches[_]
    is_gated(m.vulnerability.severity)
    count(covering_statements(m)) == 0
    msg := sprintf("%s (%s, %s): kein VEX-Statement gefunden", [m.vulnerability.id, m.artifact.name, m.vulnerability.severity])
}

# Mehr als ein passendes Statement ist kein Normalfall, sondern ein zu
# unscharfer Namensvergleich (z. B. überlappende Paketnamen in zwei
# VEX-Dateien) -> ebenfalls Abbruch, kein stilles "erstes Statement gewinnt".
deny[msg] {
    m := input.matches[_]
    is_gated(m.vulnerability.severity)
    n := count(covering_statements(m))
    n > 1
    msg := sprintf("%s (%s): mehrdeutige VEX-Abdeckung (%d Treffer) — Match zu unscharf", [m.vulnerability.id, m.artifact.name, n])
}

# Genau ein passendes Statement -> sichtbar geloggt, blockiert nicht. Gilt
# für "not_affected" und "affected" gleichermaßen, damit sich die
# Namensvergleich-Abdeckung im Step-Summary nachträglich prüfen lässt.
warn[msg] {
    m := input.matches[_]
    is_gated(m.vulnerability.severity)
    count(covering_statements(m)) == 1
    s := covering_statements(m)[0]
    msg := sprintf("%s (%s): abgedeckt durch %s, Status=%s", [m.vulnerability.id, m.artifact.name, s._source_document, s.status])
}
