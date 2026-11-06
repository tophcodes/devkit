import { View, div, svg, image } from "gpui-kit";
import { h_flex } from "gpui-base";
import { spaces, panes, terminals, run, openOverlay, theme, window, layout, settings, nextCommand, focused } from "herdr";
import { editorPane, explorerOpen, toggleEditor, toggleExplorer, splitIn, SIDEBAR } from "./editor.js";
import { helixTheme, writeTheme, applyTheme } from "./theme.js";

const isEditor = (t) => t.state === "live" && (t.argv ?? []).some((a) => a.startsWith("HERDR_OPEN=/tmp/herdr-explorer-"));

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}

export default class Tabs extends View {
  // Brings every tab's own hx onto the current herdr colors (theme.js). Runs on render,
  // which herdr repeats when the theme or the terminals change.
  syncHelix(cx) {
    const text = helixTheme(theme());
    for (const term of terminals().filter(isEditor)) {
      if (this.themed.get(term.address) === text) continue;
      const fresh = !this.themed.has(term.address);
      this.themed.set(term.address, text);
      const on = term.address.includes("/") ? term.address.split("/")[0] : null;
      cx.spawn(async () => {
        try {
          if (this.written.get(on) !== text) { await writeTheme(text, on); this.written.set(on, text); }
          await applyTheme(term.address, fresh);
        } catch { this.themed.delete(term.address); }
      });
    }
  }

  init(_props, cx) {
    this.pressed = null;
    this.themed = new Map();
    this.written = new Map();
    // keys.json's layout:workbench section sends the split keys here, so a new terminal
    // starts in the tab's folder rather than where the focused process sits.
    cx.spawn(async () => {
      for (;;) {
        const command = await nextCommand();
        const pane = focused()?.pane;
        if (pane && command === "split-right") splitIn(pane, "right");
        if (pane && command === "split-down") splitIn(pane, "down");
      }
    });
  }

  render(cx) {
    this.syncHelix(cx);
    const t = theme();
    const space = spaces().find(p => p.active);
    const shown = space?.tabs ?? [];
    const stop = (_e, cx) => cx.stop_propagation();
    const button = (id, label, action) => div().id(id).size(26).flex_none().flex().items_center().justify_center().rounded(6).text_color(t.dim).hover(s => s.bg(t.hover).text_color(t.foreground))
      .on_mouse_down("left", stop).on_click(action).child(label);
    const item = (c, i) => {
      const program = panes().find(p => p.tab === c.id && p.program?.agent)?.program ?? panes().find(p => p.tab === c.id)?.program;
      const name = /^tb\d+$/.test(c.name) ? program?.name ?? "Terminal" : c.name;
      return h_flex().id(`tab-${c.id}`).h(29).px(10).gap(7).rounded(7).items_center().flex_none().text_size(12.8)
        .border(1).border_color(c.active ? t.border : t.chrome).bg(c.active ? t.raised : t.chrome).text_color(c.active ? t.foreground : t.muted)
        .hover(s => s.bg(t.hover))
        .on_mouse_down("left", (e, cx) => { cx.stop_propagation(); this.pressed = i; if (e.click_count === 2) run("tab.rename", { id: c.id }); })
        .on_mouse_up("left", () => {
          const from = this.pressed; this.pressed = null;
          if (from !== null && from !== i) run("tab.move", { id: shown[from].id, index: space.tabs.findIndex(x => x.id === c.id) + 1 });
          else run("tab.select", { id: c.id });
        })
        .on_mouse_down("right", (_e, cx) => { cx.stop_propagation(); openOverlay({ mod: "menu", kind: "popup", width: 200, props: { tab: "tab", target: { id: c.id, space: space.id } } }); })
        .when(Boolean(program?.icon), el => el.child(program.tint ? svg(program.icon).size(14).text_color(t.muted) : image(program.icon).size(14)))
        .child(div().max_w(170).truncate().child(c.zoomed ? `${name} Z` : name))
        .when(c.status === "working", el => el.child(svg("mods/workspace-chrome/spinner.svg").size(12).flex_none().text_color(t.working).spin(900)))
        .when(c.status === "blocked" || c.status === "done", el => el.child(div().size(6).rounded(3).bg(t[c.status])))
        .when(c.active, el => el.child(div().id(`close-${c.id}`).text_color(t.dim).on_mouse_down("left", stop).on_click((_e, cx) => { cx.stop_propagation(); run("tab.close", { id: c.id }); }).child(svg("mods/pane/close.svg").size(12))));
    };
    const root = layout(), sidebar = find(root, "sidebar"), w = window();
    // Old saved rails and a dragged-narrow sidebar can be smaller than the window buttons.
    const lightsPadding = w?.platform === "macos" && w.titlebar === "none" && !w.fullscreen && root?.traffic_lights
      ? Math.max(10, (root.traffic_lights[0] + 64) / settings().zoom - (sidebar?.hidden ? 0 : sidebar?.size?.px ?? 0))
      : 10;
    const tab = shown.find(c => c.active)?.id;
    // The explorer sidebar follows the shown tab: each tab keeps whether it was open.
    if (tab && tab !== this.sidebarTab) {
      this.sidebarTab = tab;
      run(explorerOpen(tab) ? "layout.show" : "layout.hide", { id: SIDEBAR });
    }
    const paneButton = (id, label, icon, on, toggle) => h_flex().id(`pane-${id}`).h(26).px(8).gap(5).flex_none().items_center().rounded(6)
      .text_size(12).bg(on ? t.selected : t.chrome).text_color(on ? t.foreground : t.muted)
      .hover(s => s.bg(t.hover)).on_mouse_down("left", stop)
      .on_click(() => { if (tab) toggle(tab); }).child(svg(icon).size(14)).child(label);
    return h_flex().size_full().min_w(0).px(10).pl(lightsPadding).gap(3).items_center().bg(t.chrome).border_b(1).border_color(t.border)
      .on_mouse_up("left", () => { this.pressed = null; })
      .on_scroll_wheel(e => { if (Math.abs(e.delta.y) >= 1) run(e.delta.y > 0 ? "tab.prev" : "tab.next"); })
      .child(h_flex().id("tab-scroll").flex_1().min_w(0).h_full().items_center().gap(3).overflow_x_scrollbar().children(shown.map(item)))
      .child(button("tab-new", "+", () => openOverlay({ mod: "new-menu", kind: "popup", width: 250, height: 512 })))
      .when(Boolean(tab), el => el
        .child(paneButton("editor", "Editor", "mods/files/file.svg", Boolean(editorPane(tab)), toggleEditor))
        .child(paneButton("explorer", "Explorer", "mods/files/folder.svg", explorerOpen(tab), toggleExplorer)))
      .when(w?.buttons, el => el.child(button("minimize", w.platform === "windows" ? svg("mods/workbench-tabs/win-min.svg").size(16) : "−", () => run("window.minimize")))
        .child(button("maximize", w.platform === "windows" ? svg(`mods/workbench-tabs/${w.maximized ? "win-restore" : "win-max"}.svg`).size(16) : "□", () => run("window.maximize")))
        .child(button("close-window", w.platform === "windows" ? svg("mods/workbench-tabs/win-close.svg").size(16) : svg("mods/pane/close.svg").size(13), () => run("window.close"))));
  }
}
