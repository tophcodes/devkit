#!/usr/bin/env bash
# What changes between two NixOS systems: the packages, as dix lists them, then
# every file under /etc that was added, removed or now resolves to another store
# path. /etc holds the systemd units, so a changed unit shows up there even when
# no package changed.
#
# Usage: system-diff <old> <new>
# Each argument is a NixOS system (it has an etc/ folder) or a store path whose
# closure holds one, such as a microvm runner.
old="$1"
new="$2"

# The NixOS system in a closure: the path itself, or the one nixos-system-*
# path among its dependencies.
system_of() {
    if [ -d "$1/etc" ]; then
        printf '%s\n' "$1"
    else
        nix-store --query --requisites "$1" | grep -E -- '-nixos-system-[^/]*$' | head -1 || true
    fi
}

# One line per file under etc/: its path, a tab, the store path it resolves to.
# Links that leave the store (mtab to /proc, cups/ssl to /var/lib) point at
# state rather than configuration and are skipped; find's errors come from
# such targets the user may not read.
etc_files() {
    local root="$1/etc" paths=()
    mapfile -d '' paths < <(cd "$root" && find -L . -type f -printf '%P\0' 2>/dev/null)
    [ "${#paths[@]}" -gt 0 ] || return 0
    paste <(printf '%s\n' "${paths[@]}") <(cd "$root" && realpath -- "${paths[@]}") |
        awk -F '\t' 'index($2, "/nix/store/") == 1'
}

# Whether two files differ once store hashes are blanked out. A file whose
# only change is a dependency's new store path, such as a unit that names the
# new system-path, counts as unchanged; dix lists the dependency. Files kept
# in the etc derivation itself (the .mode, .uid and .gid files) get a new
# path on every build and end here too.
differs() {
    local blank='s,/nix/store/[a-z0-9]{32}-,/nix/store/-,g'
    ! cmp -s <(sed -E "$blank" "$1") <(sed -E "$blank" "$2")
}

echo "Packages:"
dix "$old" "$new"

old_system=$(system_of "$old")
new_system=$(system_of "$new")
if [ -z "$old_system" ] || [ -z "$new_system" ]; then
    echo "No NixOS system in one of the closures; /etc not compared." >&2
    exit 0
fi

echo
echo "/etc (+ added, - removed, ~ changed):"
changes=$(awk -F '\t' -v OFS='\t' '
    NR == FNR { before[$1] = $2; next }
    !($1 in before) { print "+", $1; next }
    before[$1] != $2 { print "~", $1, before[$1], $2 }
    { delete before[$1] }
    END { for (path in before) print "-", path }
' <(etc_files "$old_system") <(etc_files "$new_system") |
    while IFS=$'\t' read -r mark path before after; do
        if [ "$mark" = "~" ] && ! differs "$before" "$after"; then continue; fi
        printf '%s %s\n' "$mark" "$path"
    done | sort -k 2)
printf '%s\n' "${changes:-  (none)}"
