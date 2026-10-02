<!-- SPDX-License-Identifier: MIT -->

# OpenBunny organization defaults

This repository supplies [default community health files](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file), reusable GitHub Actions workflows, a Renovate preset, and a label taxonomy.

| Path                                                                 | Use                                                                                                  |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `CODE_OF_CONDUCT.md`, `CONTRIBUTING.md`, `SECURITY.md`, `SUPPORT.md` | GitHub applies these defaults when a repository has no file of the same type.                        |
| `.github/ISSUE_TEMPLATE/`, `.github/PULL_REQUEST_TEMPLATE.md`        | GitHub applies these templates when a repository has no corresponding templates.                     |
| `profile/README.md`                                                  | Organization profile.                                                                                |
| `.github/workflows/reusable-*.yml`                                   | Reusable checks that callers invoke explicitly.                                                      |
| `default.json`                                                       | Renovate preset; extend `github>openbunny/.github`.                                                  |
| `.github/labels.md`                                                  | Shared label names and meanings; create the labels in each repository that uses the issue templates. |
| `justfile`, `mise.toml`, `.github/workflows/ci.yml`                  | This repository's local and CI checks.                                                               |
| `LICENSE`, `LICENSES/MIT.txt`, `REUSE.toml`                          | This repository's license and metadata.                                                              |

Every project repository keeps its own `LICENSE`, `REUSE.toml`, `README.md`, and project-specific build, test, and lint gates. GitHub does not inherit licenses from this repository. A repository file of the same supported community health type takes precedence over the default. If a repository defines its own issue template or issue template configuration, it replaces the entire default issue template set. [GitHub documents these rules](https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/creating-a-default-community-health-file).

## Calling workflows

Use a commit SHA for a workflow in another repository. Each caller job grants the permissions its called workflow needs; [permissions cannot increase in a called workflow](https://docs.github.com/en/actions/how-tos/reuse-automations/reuse-workflows).

```yaml
name: CI
on: [pull_request]
permissions: {}
jobs:
  check:
    permissions:
      contents: read
    uses: openbunny/.github/.github/workflows/reusable-check.yml@<commit-sha>
    with:
      runner: macos-latest
      xcode: "26.0"
  reuse:
    permissions:
      contents: read
    uses: openbunny/.github/.github/workflows/reusable-reuse.yml@<commit-sha>
```

`reusable-check.yml` runs `just <recipe>` after mise installs tools from the caller's `mise.toml`. Inputs:

| Input             | Default         | Effect                                                                                     |
| ----------------- | --------------- | ------------------------------------------------------------------------------------------ |
| `runner`          | `ubuntu-latest` | One of the runner labels listed below; any other value fails the job.                      |
| `tools`           | empty           | Space-separated mise tools to install; empty installs every tool in `mise.toml`.           |
| `xcode`           | empty           | Xcode version to select on a macOS runner, such as `26.0`; empty keeps the runner default. |
| `recipe`          | `check`         | The `just` recipe to run.                                                                  |
| `timeout-minutes` | `30`            | Job timeout in minutes.                                                                    |

Allowed `runner` labels: `ubuntu-latest`, `ubuntu-24.04`, `ubuntu-22.04`, `macos-latest`, `macos-26`, `macos-15`. A pinned label keeps the job on one OS image when `-latest` moves to a newer one. The first step of the job compares the label with this list, so adding a label means editing the `case` in `reusable-check.yml` and this list together. `ci.yml` proves a pinned label runs by calling the workflow with `ubuntu-24.04` and `macos-26`.

A caller declares every tool its recipe needs in `mise.toml`, pinned to an exact version, or lists exact `tool@version` pairs in `tools`. The recipe installs project dependencies itself. Apps built with Xcode (scrollmark, glyphmark, and Swift packages such as openbunny-theme) set `runner: macos-latest`, and `xcode` where a specific version matters. Go (tickerbox-cli) and bun (openbunny-react) projects keep the default runner.

Other reusable workflows are `reusable-dco.yml`, `reusable-gitleaks.yml`, `reusable-reuse.yml`, `reusable-scorecard.yml`, `reusable-zizmor.yml`, and `reusable-release-please.yml`. `reusable-gitleaks.yml` and `reusable-zizmor.yml` take a `version` input that defaults to a pinned release and a `working-directory` input that defaults to `.`. Both run the tool with `mise exec <tool>@<version>`, so the tool version comes from the input and a `mise.toml` in the caller that does not list the tool does not affect the run. `ci.yml` proves this by calling both from `fixtures/caller-without-tools`, whose `mise.toml` lists neither tool. Release Please requires the caller to grant `contents: write`, `pull-requests: write`, and `issues: write`; its optional `token` secret falls back to `GITHUB_TOKEN`, which cannot trigger downstream workflows. Scorecard requires the caller to grant `id-token: write`; its `publish` input defaults to `false` and must be `true` only on a public repository. `reusable-dco.yml` skips every event other than `pull_request`.

## Visibility

Default community health files apply only while this `.github` repository is public. A private repository's reusable workflows can be called only by repositories in the same organization after its Actions access setting allows them; public repositories cannot call them. [GitHub's Actions access settings](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/enabling-features-for-your-repository/managing-github-actions-settings-for-a-repository) govern that access.

## Local checks

`just check` runs every gate that needs no container. `just --list` prints the gates and `just --show check` prints the ones `check` runs. `renovate-regex` verifies that the `default.json` custom manager for the `justfile` matches the Renovate image reference in the `justfile`, and fails on zero matches.

`just renovate-preset` validates `default.json` with `renovate-config-validator --strict` inside the pinned Renovate image. It needs docker and is not part of `just check`; CI runs it as its own job. `just check-all` runs `check` and `renovate-preset`, and fails when docker is missing instead of skipping the validation.
