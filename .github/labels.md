<!-- SPDX-License-Identifier: MIT -->

# Label taxonomy

Three prefixes: `type/*` classifies an issue, `area/*` locates it, `status/*`
tracks it through triage. Every issue and PR carries exactly one `type/*`
label; `area/*` and `status/*` are added during triage.

## type/*

| Label           | Meaning                                       |
| --------------- | --------------------------------------------- |
| `type/bug`      | Behaves differently from what it documents.   |
| `type/feature`  | A new behaviour.                              |
| `type/docs`     | Documentation only.                           |
| `type/chore`    | Build, dependency, or repository maintenance. |
| `type/security` | A vulnerability report or hardening change.   |

## area/*

| Label               | Covers                                            |
| ------------------- | ------------------------------------------------- |
| `area/ci`           | GitHub Actions workflows and the `justfile` gates |
| `area/docs`         | README, CONTRIBUTING, and other tracked docs      |
| `area/dependencies` | Dependency updates                                |
| `area/release`      | Release configuration and artefact signing        |

## status/*

| Label                 | Meaning                                                         |
| --------------------- | --------------------------------------------------------------- |
| `status/needs-triage` | Default label on a new issue; a maintainer has not reviewed it. |
| `status/confirmed`    | A maintainer reproduced the bug or accepted the proposal.       |
| `status/blocked`      | Waiting on an external dependency or decision.                  |
| `status/wontfix`      | Closed without a change; the issue states why.                  |
