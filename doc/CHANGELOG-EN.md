# Latest 10-Commit Summary

Combined highlights from the latest ten commits on `dev` (summarized, not listed one by one):

- **SUSFS toggle added and fixed**: Introduced the `cancel_susfs` option across all kernel workflows and corrected the default to boolean `false` so dispatch conditions don’t mis-evaluate; `gki-kernel.yml` now skips SUSFS patching when disabled.
- **SUKISU branch logic & guidance**: Clarified SukiSU branch selection and README notes so `stable`/`dev` expectations (bootloop risk vs. relative stability) are explicit.
- **Leaned-out build inputs**: Removed the unused `make_release` parameter to simplify workflow configs.
- **Patch integration & optimizations**: Hooked KernelSU builds to pull in Unicode zero-width bypass fixes and memory optimization patches.
- **Docs & formatting**: Added branch notices, spacing, and changelog links to the READMEs; pulled upstream workflow formatting tweaks to keep files consistent.
