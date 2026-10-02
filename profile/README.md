<!-- SPDX-License-Identifier: MIT -->

# OpenBunny

OpenBunny maintains software and shared design resources.

## Shared defaults

GitHub applies supported community health files from this public repository
where a repository does not override them:

- `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md` —
  organization defaults; a repository's own copy wins on conflict.
- `.github/ISSUE_TEMPLATE/` and `.github/PULL_REQUEST_TEMPLATE.md` —
  organization defaults for new issues and pull requests.
- `.github/workflows/reusable-*.yml` — checks every repository calls instead
  of copying; see [README.md](../README.md) for the caller form.
- `default.json` — the shared Renovate preset.

Report a vulnerability privately through the repository's **Security** tab,
not through a public issue.
