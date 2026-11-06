# Overlay that patches Helix for the herdr workbench (herdr/README.md):
# - `:diff-base [commit]` diffs every document against a commit, given as its
#   full id; without an argument, or in a repository without that commit,
#   against HEAD.
# - `:diff-base-file <path>` diffs the current document against a file.
# - The statusline element `file-stale-indicator` shows `[stale]` when the file
#   on disk changed after the document last read or wrote it.
# nixpkgs builds helix-unwrapped and wraps it as helix, so the patch goes on
# helix-unwrapped. It is appended to the patches already there, so an overlay
# applied after this one can append more.
_final: prev: {
  helix-unwrapped = prev.helix-unwrapped.overrideAttrs (old: {
    patches = (old.patches or []) ++ [./diff-base.patch];
  });
}
