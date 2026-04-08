# Security

## Reporting a vulnerability

If you discover a security issue in this repository, please **do not** open a public issue.

Instead, contact the maintainers privately (for example via GitHub Security Advisories for the repository, if enabled, or the contact method listed on the maintainer profile). Include enough detail to reproduce or understand the risk.

## Scope notes

- This project stores Dexcom credentials in **on-device** storage when the user opts in. It does not ship with any server-side component in this repo.
- Do not commit real passwords, session tokens, keystores, or `google-services.json`-style files to a public fork.
