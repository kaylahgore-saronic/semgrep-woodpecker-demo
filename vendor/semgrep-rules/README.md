# Intentionally empty

This directory is a placeholder for feature 4.8's "option B" (vendoring a snapshot of
Semgrep Registry packs for offline/reproducible CI). It was left empty on purpose --
see `docs/FINDINGS.md`'s "Offline / local-only rules" section for why: the Semgrep
Rules License v1.0 only permits internal-business-purposes use and explicitly
disallows distributing the rules or making them available to others as a service,
which a public GitHub repo would do.

Feature 4.8 is still demonstrated, just via "option A" instead: `.woodpecker/semgrep-offline.yaml`
runs only `rules/` (which we wrote and own outright) with no registry packs and no
network access at all.
