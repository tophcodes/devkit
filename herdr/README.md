# herdr workbench

The workbench is a herdr-app layout for working with coding agents: a tab bar
with an editor and an explorer per tab, pane headers, and the explorer sidebar
that shows a tab's repository and its history since the session's first write.
This folder mirrors the herdr-app home (`~/.config/herdr-app`):

- `layouts/workbench.json`: the layout.
- `mods/explorer`, `mods/workbench-tabs`, `mods/workbench-pane`: its mods.
  `editor.js` exists in all three, because a mod cannot import from another
  mod's folder. Keep the three copies identical.
- `keys.json`: the `layout:workbench` section, merged into the herdr-app
  `keys.json`. herdr-app and Toph edit that file, so it stays a real file.

A machine links the layout file and the three mod folders into its herdr-app
home as symlinks to a devkit checkout, so an edit in the checkout reloads the
running window. herdr-app writes `jsconfig.json` and `*.d.ts` into each mod
folder; `.gitignore` keeps them out.

The labels the explorer reads come from `claude-herdr-status`, the Claude Code
hook script in `packages/claude-herdr-status`; its `hooks` attribute holds the
Claude Code hooks that run it. Every machine a tab's terminals run on imports
the NixOS module `modules.nixos.herdr`: it installs jj, git and the Helix from
`overlays.helix` (`packages/helix`), registers those hooks for every Claude
Code session there, and can start herdr-core at boot. That Helix binds the
keys the mods press, in an hx started with `HERDR_OPEN` set: `alt-f12` opens a
file, `alt-f11` loads the `herdr` theme, `alt-f10` runs `:diff-base` and
`alt-f9` runs `:diff-base-file`. The explorer sets the commit the tab's hx
diffs against from the range it marks, and opens a file as a read-only
snapshot when the range ends below the working copy.

herdr-app on macOS does not reload a mod when a file behind a linked folder
changes. To work on the mods against such a machine, run
`just herdr-sync <ssh-host>`: it copies the layout file and the three mod
folders into the remote herdr-app home over SSH on every change, and the
running window there reloads. The copies replace the links on that machine;
`ln -sfh` restores them afterwards.

After a change, run `herdr-app check` on each changed mod folder.
