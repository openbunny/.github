# SPDX-License-Identifier: MIT
set shell := ["bash", "-uc"]

_default:
    @just --list

check:
    #!/usr/bin/env bash
    set -uo pipefail
    failed=0
    for gate in self-test actions-lint actions-audit tool-pins renovate-preset format reuse; do
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

renovate-preset:
    #!/usr/bin/env bash
    set -euo pipefail
    test -s default.json || { echo "renovate-preset: default.json is missing or empty" >&2; exit 1; }
    renovate-config-validator --strict default.json

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
    for tool in actionlint zizmor prettier reuse; do
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
