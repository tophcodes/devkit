// A tab's explorer: the project tree on top, the history from the base to the tip below.
// A vertical line over the history marks the range whose changes the tree colors; by
// default it runs over every commit above the base. Clicking commits selects a range (pick).
// Clicking a file opens it in the tab's own hx (editor.js).
// It sits beside the tab area as a sidebar and follows the shown tab; props { tab } pin one.
// Works on jj and git repositories, on any machine the tab lives on.
import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex, InputState, Input } from "gpui-base";
import { props, theme, watchFolder, exec, focused, home } from "herdr";
import * as vcs from "./vcs.js";
import { openInEditor, setEditorBase, snapshotPath, statePath, tabFolder, tabHistory, tabBases, machineOf } from "./editor.js";

/** The tab this explorer shows: a pinned one from props, else the window's shown tab. */
const currentTab = () => props()?.tab ?? focused()?.tab ?? null;

const COLOR = { A: "ansi2", M: "ansi4", D: "ansi1", R: "ansi8" };
// Tab -> the commit its hx was last told to diff against, kept across the sidebar's loads.
const sentBases = new Map();
const MAX_ROWS = 5000;

export default class Explorer extends View {
  init(_props, cx) {
    this.load(currentTab());
    this.refresh(cx);
    cx.timer.every(5000, (cx) => { if (this.repo?.on !== null) this.refresh(cx); });
    cx.timer.every(30000, (cx) => this.refresh(cx));
  }

  // The sidebar has one copy for every tab: switching tabs drops what was read for the
  // previous one; the next refresh reads the new tab's choices (readState).
  load(tab) {
    this.tab = tab;
    this.apply({});
    // The state file's text as last read or written; undefined until the first read.
    this.stateText = undefined;
    this.writing = Promise.resolve();
    this.sessionProjects = [];
    this.projectMenu = false;
    this.repo = null;
    this.entries = new Map();
    this.open = new Set();
    this.collapsed = new Set();
    this.changes = new Map();
    this.kinds = new Map();
    this.ignored = new Set();
    this.rows = { above: [], below: [] };
    this.hover = null;
    this.picker = null;
    this.projectsAt = 0;
    this.error = null;
    // The commit the tab's hx diffs against, and the line's upper end when it is not the
    // working copy (syncEditor).
    this.baseCommit = null;
    this.tip = null;
  }

  apply(saved) {
    this.mode = saved.mode ?? "full";
    this.base = saved.base ?? null;
    this.head = saved.head ?? null;
    this.range = saved.range ?? null;
    // The project the tree shows: null follows the tab's folder ("Auto"), a path pins one
    // workspace of the tab's session.
    this.project = saved.project ?? null;
  }

  // The choices live in the tab's state file (statePath), so windows showing the same tab
  // agree. Writes run in order, and a read waits for them, so it never undoes a choice made
  // in this window. Another window's choice shows at this window's next refresh.
  save() {
    const text = JSON.stringify({ mode: this.mode, base: this.base, head: this.head, range: this.range, project: this.project });
    const tab = this.tab, on = machineOf(tab);
    this.stateText = text;
    this.writing = this.writing.then(() => exec("sh", ["-c", 'printf %s "$2" > "$1.tmp" && mv "$1.tmp" "$1"', "state", statePath(tab), text], { on }))
      .catch(() => null);
  }

  async readState() {
    const tab = this.tab;
    await this.writing;
    // exec, which gives up after 30 s; a read that never returns would hold `loading` and
    // stop every later refresh.
    const r = await exec("sh", ["-c", 'cat "$1" 2>/dev/null; true', "state", statePath(tab)], { on: machineOf(tab) }).catch(() => null);
    const text = r?.stdout || null;
    if (this.tab !== tab || text === this.stateText) return;
    this.stateText = text;
    let saved = {};
    try { saved = JSON.parse(text ?? "{}") ?? {}; } catch { /* a broken file reads as no choices */ }
    this.apply(saved);
  }

  chooseProject(path, cx) {
    this.project = path;
    this.projectMenu = false;
    this.save();
    this.refresh(cx);
  }
  list() { return [...this.rows.above, ...this.rows.below]; }

  // Local repos refresh on file changes, ignoring jj's and git's own bookkeeping; remote
  // ones poll (watchFolder covers this machine only).
  watch(repo, cx) {
    if (repo.on !== null) return;
    cx.spawn(async (cx) => {
      try {
        while (this.repo === repo) {
          const paths = await watchFolder(repo.root);
          if (paths.some((p) => !/\/\.(jj|git)(\/|$)/.test(p.slice(repo.root.length)))) this.refresh(cx);
        }
      } catch { /* the folder went away; the next refresh detects the repo again */ }
    });
  }

  refresh(cx) {
    if (this.loading) { this.again = true; return; }
    this.loading = true;
    cx.spawn(async (cx) => {
      try {
        const auto = tabFolder(this.tab), on = machineOf(this.tab);
        if (!auto) throw new Error("No terminal in this tab");
        await this.readState();
        if (Date.now() - (this.projectsAt ?? 0) > 30000) {
          this.sessionProjects = await vcs.sessionProjects(auto, on);
          this.projectsAt = Date.now();
        }
        const folder = this.project ?? auto;
        if (!this.repo || this.repo.on !== on || !(folder + "/").startsWith(this.repo.root + "/")) {
          const first = !this.repo;
          this.repo = await vcs.detect(folder, on);
          this.entries = new Map();
          this.open = new Set();
          // Base, head and line name revisions of the previous repository.
          if (!first) { this.base = null; this.head = null; this.range = null; this.save(); }
          this.watch(this.repo, cx);
        }
        const repo = this.repo;
        if (repo.kind) {
          // null means the default: where the session started in this repository, else the
          // repository's own default (vcs.defaultBase).
          if (this.repoDefault?.repo !== repo) this.repoDefault = { repo, base: await vcs.defaultBase(repo) };
          this.defaultBase = this.sessionBase() ?? this.repoDefault.base;
          const base = this.base ?? this.defaultBase;
          this.rows = await vcs.history(repo, base, this.head);
          const span = this.span(), list = this.list();
          this.changes = !span ? new Map()
            : this.moved() ? await vcs.changes(repo, list[span.top], list[span.bottom])
            : await vcs.baseDiff(repo, base, this.head);
          this.ignored = await vcs.ignored(repo);
          await this.syncEditor(repo, base, span, list);
        }
        this.kinds = folderKinds(this.changes);
        this.index = childIndex(this.changes);
        await this.loadFolders(repo);
        this.error = null;
      } catch (e) {
        this.error = String(e?.message ?? e);
      } finally {
        this.loading = false;
        cx.notify();
        if (this.again) { this.again = false; this.refresh(cx); }
      }
    });
  }

  async loadFolders(repo) {
    if (!this.full()) return;
    for (const path of ["", ...this.open]) {
      const entries = await vcs.directory(repo, path).catch(() => []);
      if (this.repo !== repo) return;
      this.entries.set(path, entries);
    }
  }

  /** The line's ends as indexes into list(), or null when there is nothing to mark. */
  span() {
    const list = this.list(), n = this.rows.above.length;
    const fallback = n ? { top: 0, bottom: n - 1 } : null;
    if (!this.range) return fallback;
    const top = list.findIndex((r) => r.id === this.range.top), bottom = list.findIndex((r) => r.id === this.range.bottom);
    return top < 0 || bottom < 0 ? fallback : { top, bottom };
  }

  moved() {
    const s = this.span(), n = this.rows.above.length;
    return Boolean(this.range && s && (s.top !== 0 || s.bottom !== n - 1));
  }

  // The selection a click on row i would make, as on GitHub: from the default line, that
  // one commit. Then a click outside the selection extends it there, and a click inside
  // moves the nearer end in to the clicked commit. In the exact middle, `half` decides:
  // the upper half of the row moves the upper end, the lower half the lower end.
  nextSpan(i, half) {
    const s = this.range ? this.span() : null;
    let top = s?.top ?? i, bottom = s?.bottom ?? i;
    const up = i - top, down = bottom - i;
    if (i < top) top = i;
    else if (i > bottom) bottom = i;
    else if (up < down || (up === down && half === "top")) top = i;
    else bottom = i;
    return { top, bottom };
  }

  pick(i, half, cx) {
    const list = this.list(), { top, bottom } = this.nextSpan(i, half);
    this.range = { top: list[top].id, bottom: list[bottom].id };
    this.hover = null;
    this.save();
    this.refresh(cx);
  }

  reset(cx) { this.range = null; this.save(); this.refresh(cx); }

  setMode(mode, cx) {
    if (this.mode === mode) return;
    this.mode = mode;
    this.save();
    this.refresh(cx);
  }

  // The tab's hx diffs against the commit under the line's lower end, or the base while the
  // line is the default. A line whose upper end is not the working copy makes the tree open
  // files as they were in that commit: read-only snapshots (openFile).
  async syncEditor(repo, base, span, list) {
    const top = span ? list[span.top] : null, bottom = span ? list[span.bottom] : null;
    const from = !this.moved() ? base
      : repo.kind === "jj" ? `${bottom.id}-` : bottom.worktree ? "HEAD" : `${bottom.id}^`;
    this.baseCommit = await vcs.commitOf(repo, from).catch(() => null);
    const working = !top || (repo.kind === "jj" ? top.current : top.worktree);
    this.tip = working ? null : await vcs.commitOf(repo, top.id).catch(() => null);
    if (sentBases.get(this.tab) !== this.baseCommit) {
      sentBases.set(this.tab, this.baseCommit);
      await setEditorBase(this.tab, this.baseCommit);
    }
  }

  async openFile(path) {
    const repo = this.repo, file = `${repo.root}/${path}`;
    if (!this.tip) return openInEditor(this.tab, file, repo.root);
    const snap = snapshotPath(this.tab, "tip", this.tip, path), base = snapshotPath(this.tab, "base", this.baseCommit, path);
    await Promise.all([vcs.writeFileAt(repo, this.tip, path, snap), vcs.writeFileAt(repo, this.baseCommit, path, base)]);
    return openInEditor(this.tab, snap, repo.root, base);
  }

  /** The commit this repository stood at before the tab's agent first wrote to it. */
  sessionBase() { return this.repo ? tabBases(this.tab).get(this.repo.root) ?? null : null; }

  // `which`: "base" or "head". Each list starts with its default as null: the head's is
  // vcs.defaultHead, the base's the session start or the repository's default.
  openPicker(which, cx) {
    const input = InputState.new({ placeholder: "Filter refs…" });
    input.on("change", (_e, cx) => { this.picker.filter = input.value(); cx.notify(); });
    const picker = { which, input, filter: "", refs: null };
    this.picker = picker;
    input.focus();
    const repo = this.repo;
    cx.spawn(async (cx) => {
      const refs = await vcs.refs(repo, which).catch(() => []);
      if (this.picker === picker) picker.refs = which === "base" ? [null, ...refs] : refs;
      cx.notify();
    });
    cx.notify();
  }

  refLabel(which, ref) {
    if (ref !== null) return ref;
    if (which === "head") return vcs.defaultHead(this.repo);
    return this.sessionBase() ? "Session start" : this.defaultBase ?? "…";
  }

  choose(which, ref, cx) {
    this[which] = ref;
    this.range = null;
    this.picker = null;
    this.save();
    this.refresh(cx);
  }

  // A folder's children: what is on disk (full project) plus the changed paths under it.
  // In full project only deletions are added, the rest is on disk already.
  children(prefix) {
    const seen = new Map(), pre = prefix ? `${prefix}/` : "";
    if (this.full()) for (const e of this.entries.get(prefix) ?? []) seen.set(e.name, e.dir);
    const changed = this.index?.[this.full() ? "deleted" : "all"].get(prefix);
    for (const [name, dir] of changed ?? []) if (!seen.has(name)) seen.set(name, dir);
    return [...seen].map(([name, dir]) => ({ name, dir }))
      .sort((a, b) => Number(b.dir) - Number(a.dir) || a.name.localeCompare(b.name));
  }

  /** The whole tree shows: the toggle says so, or there is no repo and so no diff. */
  full() { return this.mode === "full" || !this.repo?.kind; }

  expanded(path) { return this.full() ? this.open.has(path) : !this.collapsed.has(path); }

  toggleFolder(path, cx) {
    if (this.full()) {
      if (this.open.has(path)) {
        for (const p of [...this.open]) if (p === path || p.startsWith(`${path}/`)) this.open.delete(p);
      } else {
        this.open.add(path);
        const repo = this.repo;
        cx.spawn(async (cx) => {
          const entries = await vcs.directory(repo, path).catch(() => []);
          if (this.repo === repo) this.entries.set(path, entries);
          cx.notify();
        });
      }
    } else if (this.collapsed.has(path)) this.collapsed.delete(path);
    else this.collapsed.add(path);
    cx.notify();
  }

  isIgnored(path, dir) {
    if (this.ignored.has(dir ? `${path}/` : path)) return true;
    for (let i = path.indexOf("/"); i >= 0; i = path.indexOf("/", i + 1)) if (this.ignored.has(path.slice(0, i + 1))) return true;
    return false;
  }

  kindOf(path, dir) {
    if (!dir) return this.changes.get(path) ?? null;
    const kinds = this.kinds.get(path);
    return !kinds ? null : kinds.size === 1 ? [...kinds][0] : "M";
  }

  treeRows(prefix, depth, out, t) {
    for (const entry of this.children(prefix)) {
      if (out.length >= MAX_ROWS) return out;
      const path = prefix ? `${prefix}/${entry.name}` : entry.name;
      const kind = this.kindOf(path, entry.dir), open = entry.dir && this.expanded(path);
      const color = kind ? t[COLOR[kind]] : this.isIgnored(path, entry.dir) ? t.dim : t.foreground;
      out.push(h_flex().id(`f-${path}`).h(26).flex_none().pl(8 + depth * 16).pr(10).gap(6).items_center().rounded(6)
        .cursor_pointer().hover((s) => s.bg(t.hover))
        .on_click((_e, cx) => {
          if (entry.dir) this.toggleFolder(path, cx);
          else if (kind !== "D") this.openFile(path).catch((e) => { this.error = String(e?.message ?? e); });
        })
        .child(entry.dir ? svg(`mods/files/chevron-${open ? "down" : "right"}.svg`).size(12).flex_none().text_color(t.dim) : div().w(12).flex_none())
        .child(svg(`mods/files/${entry.dir ? "folder" : "file"}.svg`).size(14).flex_none().text_color(kind ? color : t.muted))
        .child(div().flex_1().min_w(0).truncate().text_color(color).when(kind === "D", (el) => el.line_through()).child(entry.name))
        .when(Boolean(kind), (el) => el.child(div().flex_none().text_size(11).font_semibold().text_color(color).child(kind))));
      if (open) this.treeRows(path, depth + 1, out, t);
    }
    return out;
  }

  segment(t, label, mode) {
    const on = this.mode === mode;
    return div().id(`mode-${mode}`).px(8).h(22).flex().items_center().rounded(5).text_size(11.5).cursor_pointer()
      .bg(on ? t.selected : t.surface).text_color(on ? t.foreground : t.muted).hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => this.setMode(mode, cx)).child(label);
  }

  idText(full, prefix, color, t) {
    if (!full) return null;
    const head = prefix && full.startsWith(prefix) ? prefix : "";
    return h_flex().flex_none()
      .when(Boolean(head), (el) => el.child(div().font_semibold().text_color(color).child(head)))
      .child(div().text_color(head ? t.ansi8 : color).child(full.slice(head.length)));
  }

  // The line's look for a part that the current selection `now` and the hovered preview
  // `next` cover or not: kept, added (pale), removed (grey), or nothing.
  lineColor(now, next, t) {
    if (!this.hover) return now ? t.accent : null;
    return now && next ? t.accent : next ? `${t.accent.slice(0, 7)}66` : now ? t.muted : null;
  }

  commitRow(r, i, s, p, t) {
    const within = (x, lo, hi) => Boolean(x) && lo && hi;
    const inS = within(s, i >= s?.top, i <= s?.bottom), inP = within(p, i >= p?.top, i <= p?.bottom);
    const above = this.lineColor(within(s, i > s?.top, i <= s?.bottom), within(p, i > p?.top, i <= p?.bottom), t);
    const below = this.lineColor(within(s, i >= s?.top, i < s?.bottom), within(p, i >= p?.top, i < p?.bottom), t);
    const dot = this.lineColor(inS, inP, t);
    // Under a hovered preview, a commit that would change state shows a hollow dot: in
    // accent when it would be added, in grey when it would be removed.
    const hollow = Boolean(this.hover) && inP !== inS;
    const bright = r.current;
    const c = { change: bright ? t.ansi13 : t.ansi5, hash: bright ? t.ansi12 : t.ansi4, refs: bright ? t.ansi13 : t.ansi5, time: bright ? t.ansi14 : t.ansi6, author: t.ansi3 };
    const gutter = v_flex().w(18).h_full().flex_none().items_center()
      .child(div().w(2).h(9).when(Boolean(above), (el) => el.bg(above)))
      .child(!dot ? div().size(9).flex_none()
        : hollow ? div().size(9).flex_none().rounded(5).border(2).border_color(inP ? t.accent : dot)
        : div().size(9).flex_none().rounded(5).bg(dot))
      .child(div().w(2).flex_1().when(Boolean(below), (el) => el.bg(below)));
    const desc = r.desc || "(no description set)";
    // Two invisible halves over the row report hover and click for the upper and the
    // lower half; only in the exact middle of a selection does the half matter.
    const half = (which) => div().id(`c-${which}-${r.id}`).absolute().left_0().right_0().h_1_2()
      .when(which === "top", (el) => el.top_0()).when(which === "bottom", (el) => el.bottom_0())
      .on_hover((h, cx) => {
        if (h) this.hover = { i, half: which };
        else if (this.hover?.i === i && this.hover.half === which) this.hover = null;
        cx.notify();
      })
      .on_click((_e, cx) => this.pick(i, which, cx));
    return h_flex().id(`c-${r.id}`).relative().flex_none().pr(10).gap(6).cursor_pointer()
      .when(this.hover?.i === i, (el) => el.bg(t.hover))
      .child(gutter)
      .child(v_flex().flex_1().min_w(0).py(6).gap(2).text_size(12)
        .child(h_flex().gap(6).min_w(0)
          .when(Boolean(r.change), (el) => el.child(this.idText(r.change, r.changePrefix, c.change, t)))
          .when(Boolean(r.hash), (el) => el.child(this.idText(r.hash, r.hashPrefix, c.hash, t)))
          .when(Boolean(r.refs), (el) => el.child(div().min_w(0).truncate().text_color(c.refs).child(`(${r.refs})`))))
        .child(div().truncate().font_medium().text_color(r.desc ? t.foreground : t.dim).child(desc))
        .when(Boolean(r.time || r.author), (el) => el.child(h_flex().gap(6).min_w(0)
          .child(div().flex_none().text_color(c.time).child(r.time))
          .child(div().min_w(0).truncate().text_color(c.author).child(r.author)))))
      .child(half("top"))
      .child(half("bottom"));
  }

  separator(s, p, n, t) {
    const crosses = (x) => Boolean(x) && x.top < n && x.bottom >= n;
    const color = this.lineColor(crosses(s), crosses(p), t);
    return h_flex().h(14).flex_none().items_center()
      .child(v_flex().w(18).h_full().flex_none().items_center().child(div().w(2).h_full().when(Boolean(color), (el) => el.bg(color))))
      .child(div().flex_1().h(1).mr(10).bg(t.border));
  }

  historyBody(t) {
    if (this.picker) {
      const { which } = this.picker, f = this.picker.filter.toLowerCase();
      const refs = (this.picker.refs ?? []).filter((r) => this.refLabel(which, r).toLowerCase().includes(f)).slice(0, 300);
      return v_flex().flex_1().min_h(0).p(6).gap(6)
        .child(Input.new(this.picker.input).h(30).flex_none().px(8).rounded(6).border_1().border_color(t.accent).bg(t.background).text_size(12).text_color(t.foreground))
        .child(v_flex().id("refs").flex_1().min_h(0).overflow_y_scrollbar().children(
          this.picker.refs === null ? [div().p(6).text_size(12).text_color(t.dim).child("Loading refs…")]
            : refs.map((r) => div().id(`ref-${r ?? "default"}`).h(24).flex_none().px(8).flex().items_center().rounded(5).text_size(12).cursor_pointer()
              .text_color(r === this[which] ? t.accent : t.foreground).hover((s) => s.bg(t.hover))
              .on_click((_e, cx) => this.choose(which, r, cx)).child(this.refLabel(which, r)))));
    }
    const s = this.span(), n = this.rows.above.length, rows = [];
    const p = this.hover ? this.nextSpan(this.hover.i, this.hover.half) : null;
    this.rows.above.forEach((r, i) => rows.push(this.commitRow(r, i, s, p, t)));
    if (this.rows.below.length) rows.push(this.separator(s, p, n, t));
    this.rows.below.forEach((r, j) => rows.push(this.commitRow(r, n + j, s, p, t)));
    return v_flex().id("history").flex_1().min_h(0).overflow_y_scrollbar().py(4)
      .on_hover((h, cx) => { if (!h && this.hover !== null) { this.hover = null; cx.notify(); } })
      .children(rows);
  }

  projectButton(t) {
    const repo = this.repo?.root?.split("/").pop() ?? "";
    return h_flex().id("project").px(8).h(22).flex_none().items_center().gap(4).rounded(5).text_size(11.5).cursor_pointer()
      .bg(this.projectMenu ? t.selected : t.surface).hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => { this.projectMenu = !this.projectMenu; cx.notify(); })
      .when(!this.project, (el) => el.child(div().text_color(t.muted).child("Auto")))
      .child(div().max_w(160).truncate().text_color(t.foreground).child(repo))
      .child(div().text_color(t.dim).child("▾"));
  }

  /** What can be picked besides "Auto": the session's workspaces, then the repositories
   *  the agent wrote to lately, without the one Auto shows now. */
  choices() {
    if (!this.tab) return [];
    const auto = tabFolder(this.tab), seen = new Set([auto]), out = [];
    const history = tabHistory(this.tab).map((path) => ({ name: path.split("/").pop(), path }));
    for (const p of [...this.sessionProjects, ...history]) {
      if (seen.has(p.path)) continue;
      seen.add(p.path);
      out.push(p);
    }
    return out;
  }

  projectList(t) {
    const item = (id, label, detail, chosen, path) => h_flex().id(`project-${id}`).h(26).flex_none().px(10).gap(8).items_center()
      .text_size(12).cursor_pointer().hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => this.chooseProject(path, cx))
      .child(div().flex_none().text_color(chosen ? t.accent : t.foreground).child(label))
      .child(div().flex_1().min_w(0).truncate().text_color(t.dim).child(detail));
    const home = (p) => p.replace(/^\/home\/[^/]+|^\/Users\/[^/]+/, "~");
    return v_flex().flex_none().py(4).border_b(1).border_color(t.border).bg(t.surface)
      .child(item("auto", "Auto", home(tabFolder(this.tab) ?? ""), !this.project, null))
      .children(this.choices().map((p) => item(p.path, p.name, home(p.path), this.project === p.path, p.path)));
  }

  refButton(t, which, label) {
    const open = this.picker?.which === which;
    return div().id(`pick-${which}`).px(8).h(22).flex().items_center().gap(4).rounded(5).text_size(11.5).cursor_pointer()
      .bg(open ? t.selected : t.surface).text_color(t.foreground).hover((s) => s.bg(t.hover))
      .on_click((_e, cx) => { if (open) { this.picker = null; cx.notify(); } else this.openPicker(which, cx); })
      .child(div().text_color(t.muted).child(label))
      .child(div().max_w(140).truncate().child(this.refLabel(which, this[which])))
      .child(div().text_color(t.dim).child("▾"));
  }

  bar(t) { return h_flex().h(36).flex_none().px(10).gap(6).items_center().border_b(1).border_color(t.border); }

  render(cx) {
    const tab = currentTab();
    if (tab !== this.tab) {
      this.load(tab);
      // A refresh still reading the previous tab runs once more for this one.
      if (this.loading) this.again = true;
      else this.refresh(cx);
    }
    const t = theme();
    const tree = this.treeRows("", 0, [], t);
    const status = this.error ?? (this.loading && !this.entries.size && !this.changes.size ? "Loading…" : null);
    const folder = (this.repo?.root ?? "").replace(home(), "~");
    return v_flex().id("explorer").size_full().min_h(0).bg(t.background).text_color(t.foreground).text_size(13)
      .child(h_flex().h(30).flex_none().px(12).gap(8).items_center().border_b(1).border_color(t.border).text_size(12)
        .child(div().flex_none().font_medium().child("Explorer"))
        .child(div().flex_1().min_w(0).truncate().text_color(t.dim).child(folder)))
      .child(this.bar(t)
        .when(Boolean(this.repo?.kind), (el) => el
          .child(this.segment(t, "Full project", "full"))
          .child(this.segment(t, "Diff only", "diff")))
        .child(div().flex_1())
        // A pick only exists when the tab's session holds more than one project.
        .when(this.choices().length > 0, (el) => el.child(this.projectButton(t))))
      .when(this.projectMenu, (el) => el.child(this.projectList(t)))
      .child(this.repo?.kind ? this.split(t, tree, status) : this.treeList(t, tree, status).flex_1());
  }

  treeList(t, tree, status) {
    return v_flex().id("tree").min_h(0).overflow_y_scrollbar().p(6).children(tree)
      .when(Boolean(status) || !tree.length, (el) => el.child(div().p(8).text_size(12).text_color(t.dim)
        .child(status ?? (!this.full() ? "No changes in this range" : "Empty folder"))));
  }

  // Tree and history share the space below the top bar. Dragging the handle between them
  // moves the border; dragged within FOLD px of an edge, the part there folds away and
  // only the history's own bar stays. The split is the sidebar's, kept across restarts.
  split(t, tree, status) {
    const FOLD = 40, { share, folded } = this.splitState();
    const height = this.splitHeight ?? 0;
    const historyBar = this.bar(t).border_t(1)
      .child(this.refButton(t, "base", "Base"))
      .child(this.refButton(t, "head", "Head"))
      .child(div().flex_1())
      .when(this.moved(), (el) => el.child(div().id("reset").px(8).h(22).flex().items_center().rounded(5).text_size(11.5).cursor_pointer()
        .text_color(t.muted).hover((s) => s.bg(t.hover).text_color(t.foreground))
        .on_click((_e, cx) => this.reset(cx)).child("Reset")));
    const handle = div().id("split-handle").h(7).flex_none().flex().items_center().justify_center()
      .cursor_row_resize().hover((s) => s.bg(t.hover))
      .on_mouse_down("left", (_e, cx) => { this.dragging = true; cx.stop_propagation(); })
      .child(div().w(32).h(3).rounded(2).bg(this.dragging ? t.accent : t.border));
    const stop = (cx) => {
      if (!this.dragging) return;
      this.dragging = false;
      try { localStorage.setItem("split", JSON.stringify(this.splitState())); } catch { /* per-viewer only */ }
      cx.notify();
    };
    return v_flex().id("split").flex_1().min_h(0)
      .on_size_change((size, cx) => { this.splitHeight = size.height; cx.notify(); })
      .on_mouse_move((e, cx) => {
        if (!this.dragging) return;
        const y = e.local_position.y, h = e.bounds.height;
        this.splitValue = y < FOLD ? { share, folded: "tree" }
          : y > h - FOLD ? { share, folded: "history" }
          : { share: y / h, folded: null };
        cx.notify();
      })
      .on_mouse_up("left", (_e, cx) => stop(cx))
      .on_hover((hovered, cx) => { if (!hovered) stop(cx); })
      .when(folded !== "tree", (el) => el.child(folded === "history"
        ? this.treeList(t, tree, status).flex_1()
        : this.treeList(t, tree, status).flex_none().h(Math.max(0, height * share - 4))))
      .child(handle)
      .child(historyBar)
      .when(folded !== "history", (el) => el.child(this.historyBody(t)));
  }

  splitState() {
    if (!this.splitValue) {
      try { this.splitValue = JSON.parse(localStorage.getItem("split") ?? "null"); } catch { /* per-viewer only */ }
      this.splitValue ??= { share: 0.5, folded: null };
    }
    return this.splitValue;
  }
}

/** For each folder ("" is the root), its direct children that a change touches, as
 *  name -> is a folder: `all` for every change, `deleted` for deletions only. */
function childIndex(changes) {
  const index = { all: new Map(), deleted: new Map() };
  const add = (map, folder, name, dir) => {
    if (!map.has(folder)) map.set(folder, new Map());
    const names = map.get(folder);
    if (!names.has(name)) names.set(name, dir);
  };
  for (const [path, kind] of changes) {
    const parts = path.split("/");
    parts.forEach((name, i) => {
      const folder = parts.slice(0, i).join("/"), dir = i < parts.length - 1;
      add(index.all, folder, name, dir);
      if (kind === "D") add(index.deleted, folder, name, dir);
    });
  }
  return index;
}

/** For each folder, the kinds of change somewhere below it. */
function folderKinds(changes) {
  const out = new Map();
  for (const [path, kind] of changes) {
    for (let i = path.indexOf("/"); i >= 0; i = path.indexOf("/", i + 1)) {
      const folder = path.slice(0, i);
      if (!out.has(folder)) out.set(folder, new Set());
      out.get(folder).add(kind);
    }
  }
  return out;
}
