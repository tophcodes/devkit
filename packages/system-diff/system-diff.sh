#!/usr/bin/env bash
# What changes between two NixOS systems: the packages, as dix lists them, then
# every file under /etc that was added, removed or now resolves to another store
# path, and for each changed text file its diff. /etc holds the systemd units,
# so a changed unit shows up there even when no package changed.
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
blank() { sed -E 's,/nix/store/[a-z0-9]{32}-,/nix/store/-,g' "$1"; }
differs() { ! cmp -s <(blank "$1") <(blank "$2"); }

# A diff longer than this many lines is cut, so one large file (a generated
# config) does not bury the rest; `diff` on the two store paths shows it whole.
max_lines=50

# The unified diff of a changed file, store hashes blanked out, cut at
# max_lines. Binary files get a one-line note instead.
show_diff() {
    local path="$1" before="$2" after="$3" body count
    echo
    if ! grep -qI . "$before" || ! grep -qI . "$after"; then
        echo "$path: binary or empty, not shown"
        return
    fi
    body=$(diff -u --label "old/$path" --label "new/$path" <(blank "$before") <(blank "$after") || true)
    count=$(wc -l <<<"$body")
    head -n "$max_lines" <<<"$body"
    if [ "$count" -gt "$max_lines" ]; then
        echo "... $((count - max_lines)) more lines: diff $before $after"
    fi
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
        printf '%s\t%s\t%s\t%s\n' "$mark" "$path" "$before" "$after"
    done | sort -t $'\t' -k 2)
if [ -z "$changes" ]; then
    echo "  (none)"
    exit 0
fi
cut -f 1,2 <<<"$changes" | tr '\t' ' '

# A unit linked from a *.wants/ folder resolves to the same files as the unit
# itself; its diff shows once, under the first path.
declare -A shown=()
while IFS=$'\t' read -r mark path before after; do
    [ "$mark" = "~" ] || continue
    [ -z "${shown[$before $after]:-}" ] || continue
    shown[$before $after]=1
    show_diff "$path" "$before" "$after"
done <<<"$changes"
