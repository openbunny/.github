# SPDX-License-Identifier: MIT
set shell := ["bash", "-uc"]

_default:
    @just --list

check:
    #!/usr/bin/env bash
    set -uo pipefail
    failed=0
    for gate in self-test actions-lint actions-audit tool-pins renovate-regex format reuse; do
        printf '\njust %s\n' "$gate"
        just "$gate" || failed=1
    done
    exit "$failed"

# Runs `check` and `renovate-preset`; fails when docker is missing.
check-all:
    #!/usr/bin/env bash
    set -uo pipefail
    command -v docker >/dev/null || { echo "check-all: docker is not installed; renovate-preset needs it" >&2; exit 1; }
    failed=0
    for gate in check renovate-preset; do
        printf '\njust %s\n' "$gate"
        just "$gate" || failed=1
    done
    exit "$failed"

actions-lint:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="${CHECK_WORKFLOWS_DIR:-.github/workflows}"
    shopt -s nullglob
    files=("$dir"/*.yml "$dir"/*.yaml)
    ((${#files[@]})) || { echo "actionlint: no workflow files in $dir" >&2; exit 1; }
    actionlint "${files[@]}"

actions-audit:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="${CHECK_WORKFLOWS_DIR:-.github/workflows}"
    shopt -s nullglob
    files=("$dir"/*.yml "$dir"/*.yaml)
    ((${#files[@]})) || { echo "zizmor: no workflow files in $dir" >&2; exit 1; }
    zizmor --persona=pedantic "${files[@]}"

tool-pins:
    #!/usr/bin/env bash
    set -euo pipefail
    file="${CHECK_MISE_FILE:-mise.toml}"
    tools=$(sed -n '/^\[tools\]/,/^\[/p' "$file" | grep -E '^[^#[[:space:]\[].*=' || true)
    [ -n "$tools" ] || { echo "tool-pins: no tools in $file" >&2; exit 1; }
    unpinned=$(grep -vE '= "[0-9]+\.[0-9]+\.[0-9]+"$' <<<"$tools" || true)
    [ -z "$unpinned" ] || { echo "tool-pins: not pinned to an exact version in $file:" >&2; echo "$unpinned" >&2; exit 1; }

renovate-regex:
    #!/usr/bin/env bash
    set -euo pipefail
    export PRESET="${CHECK_PRESET_FILE:-default.json}" TARGET="${CHECK_RENOVATE_TARGET:-justfile}"
    node - <<'JS'
    const fs = require("node:fs");
    const preset = JSON.parse(fs.readFileSync(process.env.PRESET, "utf8"));
    const manager = (preset.customManagers ?? []).find((m) => (m.managerFilePatterns ?? []).includes("/^justfile$/"));
    if (!manager) { console.error(`renovate-regex: no custom manager for justfile in ${process.env.PRESET}`); process.exit(1); }
    const text = fs.readFileSync(process.env.TARGET, "utf8");
    const matches = manager.matchStrings.flatMap((pattern) => [...text.matchAll(new RegExp(pattern, "g"))]);
    if (matches.length === 0) { console.error(`renovate-regex: no match in ${process.env.TARGET}`); process.exit(1); }
    for (const { groups } of matches) {
      if (!groups?.currentValue || !groups?.currentDigest) { console.error("renovate-regex: match lacks currentValue or currentDigest"); process.exit(1); }
    }
    JS

# Needs docker and pulls the Renovate image; not part of `just check`. Run it through `just check-all`.
renovate-preset:
    #!/usr/bin/env bash
    set -euo pipefail
    test -s default.json || { echo "renovate-preset: default.json is missing or empty" >&2; exit 1; }
    command -v docker >/dev/null || { echo "renovate-preset: docker is not installed" >&2; exit 1; }
    docker run --rm --entrypoint renovate-config-validator -v "$PWD/default.json:/work/default.json:ro" -w /work ghcr.io/renovatebot/renovate:44.132.2@sha256:0191afbc3937e5316263426fc0ce1450f5c143d42e3f91da8c6f771e317fae51 --strict default.json

format:
    #!/usr/bin/env bash
    set -euo pipefail
    root="${CHECK_FORMAT_ROOT:-.}"
    files=()
    while IFS= read -r file; do files+=("$file"); done < <(find "$root" -path "$root/.git" -prune -o -type f \( -name '*.md' -o -name '*.yml' -o -name '*.json' \) -print)
    ((${#files[@]})) || { echo "prettier: no format targets in $root" >&2; exit 1; }
    prettier --check "${files[@]}"

reuse:
    #!/usr/bin/env bash
    set -euo pipefail
    root="${CHECK_REUSE_ROOT:-.}"
    test -n "$(find "$root" -type f -not -path '*/.git/*' -print -quit)" || { echo "reuse: no files in $root" >&2; exit 1; }
    cd "$root"
    reuse lint

self-test:
    #!/usr/bin/env bash
    set -euo pipefail
    for tool in actionlint zizmor prettier reuse node; do
        command -v "$tool" >/dev/null || { echo "self-test: $tool is not installed" >&2; exit 1; }
    done
    fixture=$(mktemp -d "${TMPDIR:-/tmp}/gate-fixtures.XXXXXX")
    trap 'rm -rf "$fixture"' EXIT
    mkdir "$fixture/workflows" "$fixture/format" "$fixture/reuse" "$fixture/empty"
    cat > "$fixture/workflows/bad.yml" <<'YAML'
    name: bad
    on: [push
    YAML
    if CHECK_WORKFLOWS_DIR="$fixture/workflows" just actions-lint >/dev/null 2>&1; then echo 'actionlint accepted invalid YAML' >&2; exit 1; fi
    cat > "$fixture/workflows/bad.yml" <<'YAML'
    name: bad
    on: push
    permissions: write-all
    jobs:
      check:
        runs-on: ubuntu-latest
        steps:
          - run: echo bad
    YAML
    if CHECK_WORKFLOWS_DIR="$fixture/workflows" just actions-audit >/dev/null 2>&1; then echo 'zizmor accepted write-all permissions' >&2; exit 1; fi
    printf '[tools]\njust = "latest"\n' > "$fixture/unpinned.toml"
    if CHECK_MISE_FILE="$fixture/unpinned.toml" just tool-pins >/dev/null 2>&1; then echo 'tool-pins accepted an unpinned tool' >&2; exit 1; fi
    printf '[settings]\n' > "$fixture/notools.toml"
    if CHECK_MISE_FILE="$fixture/notools.toml" just tool-pins >/dev/null 2>&1; then echo 'tool-pins accepted an empty target set' >&2; exit 1; fi
    printf '{"customManagers":[{"managerFilePatterns":["/^justfile$/"],"matchStrings":["ghcr\\\\.io/x:(?<currentValue>[^@]+)@(?<currentDigest>sha256:[a-f0-9]{64})"]}]}' > "$fixture/preset.json"
    printf 'no image here\n' > "$fixture/nomatch"
    if CHECK_PRESET_FILE="$fixture/preset.json" CHECK_RENOVATE_TARGET="$fixture/nomatch" just renovate-regex >/dev/null 2>&1; then echo 'renovate-regex accepted a target with no match' >&2; exit 1; fi
    printf '{}' > "$fixture/nomanager.json"
    if CHECK_PRESET_FILE="$fixture/nomanager.json" just renovate-regex >/dev/null 2>&1; then echo 'renovate-regex accepted a preset with no justfile manager' >&2; exit 1; fi
    printf '# Bad\n\n-   spacing\n' > "$fixture/format/bad.md"
    if CHECK_FORMAT_ROOT="$fixture/format" just format >/dev/null 2>&1; then echo 'prettier accepted invalid formatting' >&2; exit 1; fi
    printf 'no license metadata\n' > "$fixture/reuse/bad.txt"
    if CHECK_REUSE_ROOT="$fixture/reuse" just reuse >/dev/null 2>&1; then echo 'reuse accepted missing license metadata' >&2; exit 1; fi
    for gate in actions-lint actions-audit format reuse; do
        case "$gate" in
            actions-*) if CHECK_WORKFLOWS_DIR="$fixture/empty" just "$gate" >/dev/null 2>&1; then echo "$gate accepted an empty target set" >&2; exit 1; fi ;;
            format) if CHECK_FORMAT_ROOT="$fixture/empty" just "$gate" >/dev/null 2>&1; then echo "$gate accepted an empty target set" >&2; exit 1; fi ;;
            reuse) if CHECK_REUSE_ROOT="$fixture/empty" just "$gate" >/dev/null 2>&1; then echo "$gate accepted an empty target set" >&2; exit 1; fi ;;
        esac
    done
