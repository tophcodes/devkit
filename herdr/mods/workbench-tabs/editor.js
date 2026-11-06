// The tab's own hx: at most one per tab, found by the HERDR_OPEN marker in its argv.
// Opening a file writes the path to the HERDR_OPEN file and presses alt-f12, which the
// helix config binds to `:open` on that file's content (herdr-core cannot type ":").
// Only the tab's own hx is touched; any other hx in the tab stays as it is.
// hx, the handoff file and `hc keys` all run on the machine the tab's space lives on.
// This file exists in mods/explorer, mods/workbench-tabs and mods/workbench-pane: a mod
// cannot import from another mod's folder. Keep the copies identical.
import { terminals, panes, spaces, run, exec, shared, setShared } from "herdr";

export const EXPLORER = "explorer";

const local = (id) => id.split("/").pop();
/** The machine a tab lives on, null for this one. */
export const machineOf = (tab) => spaces().find((s) => s.tabs.some((t) => t.id === tab))?.machine ?? null;
const handoff = (tab) => `/tmp/herdr-explorer-${local(tab)}`;
const marker = (tab) => `HERDR_OPEN=${handoff(tab)}`;

/** The tab's hx terminal while hx still runs in it, else null. */
export function editorOf(tab) {
  if (!tab) return null;
  const m = marker(tab);
  return terminals().find((t) => t.state === "live" && (t.argv ?? []).includes(m)
    && /(^|\/)hx$/.test(t.foreground?.argv?.[0] ?? "hx")) ?? null;
}

export const tabPanes = (tab) => panes().filter((p) => p.tab === tab);
export const editorPane = (tab) => {
  const ed = editorOf(tab);
  return ed ? tabPanes(tab).find((p) => p.terminal === ed.address) ?? null : null;
};

/** A terminal pane's folder: the `herdr.folder` label an agent sets (claude-herdr-status
 *  writes Claude Code's working folder there), else the process's own folder. */
export function paneFolder(pane) {
  const label = pane?.terminal ? terminals().find((t) => t.address === pane.terminal)?.labels?.["herdr.folder"] : null;
  return label || pane?.cwd || null;
}

// The pane that decides the tab's folder: its first agent, else its first terminal, never
// the editor. A second agent in the tab does not move it.
function leadPane(tab) {
  const ed = editorOf(tab);
  const shells = tabPanes(tab).filter((p) => p.terminal && p.terminal !== ed?.address);
  return shells.find((p) => p.program?.agent || p.status) ?? shells[0];
}

/** The folder this tab works in. */
export const tabFolder = (tab) => paneFolder(leadPane(tab));

const leadLabel = (tab, name) => {
  const term = tab ? leadPane(tab)?.terminal : null;
  return term ? terminals().find((t) => t.address === term)?.labels?.[name] ?? null : null;
};

/** The repositories the tab's agent wrote to lately, newest first (`herdr.folders`). */
export function tabHistory(tab) {
  const value = leadLabel(tab, "herdr.folders");
  return value ? value.split(":").filter(Boolean) : [];
}

/** Repository root -> the commit it stood at before the tab's agent first wrote to it
 *  (`herdr.bases`, `<root>=<commit>` joined by ":"). */
export function tabBases(tab) {
  const value = leadLabel(tab, "herdr.bases") ?? "";
  return new Map(value.split(":").filter((e) => e.includes("=")).map((e) => {
    const cut = e.lastIndexOf("=");
    return [e.slice(0, cut), e.slice(cut + 1)];
  }));
}

/** Splits a terminal off `pane`, starting in the tab's folder. */
export function splitIn(pane, direction) {
  const p = panes().find((x) => x.pane === pane);
  if (!p) return;
  run("pane.focus", { pane });
  run("terminal.open", { folder: tabFolder(p.tab) ?? undefined, place: direction });
}

// A new or returning hx goes right of the tab's last pane and is zoomed: it fills the tab,
// and the explorer sidebar beside the tab area stays visible.
// Ceiling: terminal.open acts on one pane, so in a tab split downward the unzoomed hx sits
// beside the last pane only, not as a full-height column.
async function placeEditor(tab, start) {
  const last = tabPanes(tab).at(-1);
  if (last) run("pane.focus", { pane: last.pane });
  start();
  // The new pane shows up once the core has answered; wait up to two seconds for it.
  for (let i = 0; i < 10; i++) {
    const pane = editorPane(tab);
    if (pane) {
      if (!pane.zoomed) run("pane.zoom", { pane: pane.pane });
      return;
    }
    await exec("sleep", ["0.2"]).catch(() => null);
  }
}

const startEditor = (tab, file, folder) => placeEditor(tab, () => run("terminal.open", {
  argv: ["env", marker(tab), "hx", ...(file ? [file] : [])], folder: folder ?? tabFolder(tab) ?? undefined, place: "right" }));
const showEditor = (tab, ed) => placeEditor(tab, () => run("terminal.keep", { terminal: ed.address, place: "right" }));

/** Opens a file (absolute path on the tab's machine) in the tab's hx: starts hx when none
 *  runs, shows a parked one. */
export async function openInEditor(tab, file, folder) {
  const on = machineOf(tab);
  await exec("sh", ["-c", 'printf %s "$2" > "$1"', "handoff", handoff(tab), file], { on });
  const ed = editorOf(tab);
  if (!ed) { await startEditor(tab, file, folder); return; }
  if (!editorPane(tab)) await showEditor(tab, ed);
  else run("pane.focus", { terminal: ed.address });
  await exec("hc", ["keys", local(ed.address), "esc", "alt+f12"], { on });
}

/** The tab bar's Editor button: hide (park; hx keeps running), show, or start hx. */
export function toggleEditor(tab) {
  const ed = editorOf(tab);
  if (ed && editorPane(tab)) run("terminal.park", { terminal: ed.address });
  else if (ed) showEditor(tab, ed);
  else startEditor(tab, null, null);
}

// The explorer is a sidebar block in the layout, beside the tab area. It is shown or
// hidden per tab: the choice is kept in shared state and applied when a tab is shown.
export const SIDEBAR = "explorer-sidebar";
const openKey = (tab) => `explorer.open:${tab}`;
export const explorerOpen = (tab) => Boolean(shared(openKey(tab)));

/** The tab bar's Explorer button: show or hide the sidebar for this tab. */
export function toggleExplorer(tab) {
  const open = !explorerOpen(tab);
  setShared(openKey(tab), open);
  run(open ? "layout.show" : "layout.hide", { id: SIDEBAR });
}
