set shell := ["bash", "-euo", "pipefail", "-c"]

lib_dir := home_directory() / ".local/lib/axe"
bin := home_directory() / ".local/bin/axe"

_default:
    @just --list --unsorted --list-heading '' --list-prefix='- '

# rebase the fork commit onto upstream and force-push main to the fork
pull:
    #!/usr/bin/env bash
    set -euo pipefail
    [[ "$(git branch --show-current)" == main ]] || { echo "✗ switch to main first"; exit 1; }
    echo "→ fetching origin and upstream"
    git fetch origin
    git fetch --tags upstream
    # main is force-pushed, so refuse to drop commits that only exist on origin
    git merge-base --is-ancestor origin/main HEAD || { echo "✗ origin/main has commits missing locally, reconcile them first"; exit 1; }
    echo "→ rebasing main onto upstream/main"
    git rebase --autostash upstream/main || { echo "✗ resolve conflicts, run git rebase --continue, then git push --force-with-lease origin main"; exit 1; }
    echo "→ force-pushing to origin"
    git push --force-with-lease origin main
    echo "✓ pull complete"

# clone pinned IDB and build its XCFrameworks (slow)
setup:
    #!/usr/bin/env bash
    set -euo pipefail
    command -v xcodegen >/dev/null || { echo "✗ xcodegen required: brew install xcodegen"; exit 1; }
    log=$(mktemp); trap 'rm -f "$log"' EXIT
    run_quiet() {
        local label="$1"; shift
        echo "→ $label"
        "$@" >"$log" 2>&1 || { local rc=$?; echo "✗ $label failed:" >&2; cat "$log" >&2; exit $rc; }
    }
    # same steps as test-runner.sh: the signing steps of build.sh need a Developer ID
    for step in setup clean frameworks install strip xcframeworks; do
        run_quiet "build.sh $step" scripts/build.sh "$step"
    done
    run_quiet "resolving swift packages" swift package resolve
    echo "✓ setup complete"

# build release axe and install to ~/.local/bin
install:
    #!/usr/bin/env bash
    set -euo pipefail
    compgen -G "build_products/XCFrameworks/*.xcframework" >/dev/null || { echo "✗ IDB frameworks missing, run 'just setup' first"; exit 1; }
    if [[ -e "{{ bin }}" ]] && ! grep -qF "{{ lib_dir }}/axe" "{{ bin }}"; then
        read -r -p "{{ bin }} was not installed by this justfile, overwrite? [y/N] " ans
        [[ "$ans" == [yY] ]] || { echo "aborted."; exit 1; }
    fi
    log=$(mktemp); trap 'rm -f "$log"' EXIT
    run_quiet() {
        local label="$1"; shift
        echo "→ $label"
        "$@" >"$log" 2>&1 || { local rc=$?; echo "✗ $label failed:" >&2; cat "$log" >&2; exit $rc; }
    }
    # VersionPlugin declares no inputs, so SwiftPM never regenerates the version by itself
    find .build/plugins -path "*/VersionPlugin/Version.swift" -delete 2>/dev/null || true
    version="$(git describe --tags --always --dirty)+fork"
    run_quiet "building release axe $version" env AXE_VERSION="$version" swift build -c release
    out=$(swift build -c release --show-bin-path)
    echo "→ copying to {{ lib_dir }}"
    # a fresh inode keeps macOS from killing the new binary on a stale code-signature cache
    rm -rf "{{ lib_dir }}"
    mkdir -p "{{ lib_dir }}" "$(dirname "{{ bin }}")"
    cp -R "$out/axe" "$out/AXe_AXe.bundle" "$out"/*.framework "{{ lib_dir }}/"
    # exec wrapper instead of symlink so axe finds its frameworks and bundle beside the real path
    printf '#!/bin/bash\nexec "%s" "$@"\n' "{{ lib_dir }}/axe" > "{{ bin }}"
    chmod 755 "{{ bin }}"
    echo "✓ installed: $("{{ bin }}" --version)"

# remove installed axe and all build outputs
uninstall:
    #!/usr/bin/env bash
    set -euo pipefail
    targets=()
    if [[ -e "{{ bin }}" ]] && grep -qF "{{ lib_dir }}/axe" "{{ bin }}"; then
        targets+=("{{ bin }}")
    fi
    for path in "{{ lib_dir }}" .build idb_checkout build_products build_derived_data; do
        if [[ -e "$path" ]]; then targets+=("$path"); fi
    done
    [[ ${#targets[@]} -eq 0 ]] && { echo "nothing to remove."; exit 0; }
    for path in "${targets[@]}"; do
        echo "  $path ($(du -sh "$path" | cut -f1))"
    done
    read -r -p "remove these? [y/N] " ans
    [[ "$ans" == [yY] ]] || { echo "aborted."; exit 1; }
    rm -rf "${targets[@]}"
    echo "✓ removed"
