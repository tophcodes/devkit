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
hook script in `packages/claude-herdr-status`. The Helix keys the mods press
(`alt-f12` opens a file, `alt-f11` loads the `herdr` theme) are bound in each
machine's Helix configuration.

After a change, run `herdr-app check` on each changed mod folder.
