# Overlay that patches Helix for the herdr workbench (herdr/README.md):
# - `:diff-base [commit]` diffs every document against a commit, given as its
#   full id; without an argument, or in a repository without that commit,
#   against HEAD.
# - `:diff-base-file <path>` diffs the current document against a file.
# - The statusline element `file-stale-indicator` shows `[stale]` when the file
#   on disk changed after the document last read or wrote it.
# - When HERDR_OPEN is set, which only the workbench mods do when they start
#   hx, A-F12, A-F11, A-F10 and A-F9 run the commands the mods press them for.
#   These bindings merge after the user and workspace configs, so neither can
#   shadow them; outside the workbench the keys stay unbound.
# nixpkgs builds helix-unwrapped and wraps it as helix, so the patches go on
# helix-unwrapped. They are appended to the patches already there, so an
# overlay applied after this one can append more.
_final: prev: {
  helix-unwrapped = prev.helix-unwrapped.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./diff-base.patch ./herdr-keys.patch];
  });
}
