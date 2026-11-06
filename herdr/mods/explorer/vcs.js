// Repository facts for the explorer, from jj or git. Every function takes the repo
// `{ kind: "jj" | "git" | null, root, on }` (`on`: the machine it lives on, null for this
// one) and returns plain data. Everything runs on that machine.
//
// History rows: { id, change, changePrefix, hash, hashPrefix, refs, desc, time, author, current, worktree }.
// jj rows use the change id as `id`: it survives the working-copy snapshots that rewrite @.
// Changes: Map<path relative to root, "A" | "M" | "D" | "R">.
import { exec } from "herdr";

const US = "\x1f", RS = "\x1e";
const BELOW = 5;
// Ceiling: the history shows at most this many commits above the base, newest first, so a
// base far back (a repository without a remote) cannot stall rendering. The default diff
// still runs from the base itself (baseDiff); only the line covers the shown rows.
const ABOVE = 100;

// git gets --no-optional-locks: it then writes nothing under .git, so the folder watch
// does not fire on the explorer's own reads.
async function run(repo, cmd, args) {
  const r = await exec(cmd, cmd === "git" ? ["--no-optional-locks", ...args] : args, { cwd: repo.root, on: repo.on });
  if (r.code !== 0) throw new Error((r.stderr || `${cmd} failed`).trim().split("\n")[0]);
  return r.stdout;
}

/** The repository the folder is in, preferring jj; a plain folder gets kind null. */
export async function detect(folder, on) {
  const jj = await exec("jj", ["root", "--ignore-working-copy"], { cwd: folder, on }).catch(() => null);
  if (jj?.code === 0) return { kind: "jj", root: jj.stdout.trim(), on };
  const git = await exec("git", ["rev-parse", "--show-toplevel"], { cwd: folder, on }).catch(() => null);
  if (git?.code === 0) return { kind: "git", root: git.stdout.trim(), on };
  return { kind: null, root: folder, on };
}

/** The base a repo starts with: jj's trunk(), git's remote default branch. Without a
 *  remote, jj's trunk() is the root commit, so a local main, master or trunk wins then. */
export async function defaultBase(repo) {
  if (repo.kind === "jj") {
    const local = await run(repo, "jj", ["log", "--no-graph", "--ignore-working-copy", "-r",
      "trunk() & root()", "-T", '"root"']).catch(() => "");
    if (!local.includes("root")) return "trunk()";
    const names = await run(repo, "jj", ["bookmark", "list", "-T", 'name ++ "\\n"']).catch(() => "");
    return ["main", "master", "trunk"].find((n) => names.split("\n").includes(n)) ?? "trunk()";
  }
  const head = await run(repo, "git", ["rev-parse", "--abbrev-ref", "origin/HEAD"]).catch(() => "");
  if (head.trim() && head.trim() !== "origin/HEAD") return head.trim();
  for (const name of ["main", "master", "trunk"]) {
    if (await run(repo, "git", ["rev-parse", "--verify", "--quiet", name]).then(() => true, () => false)) return name;
  }
  return "HEAD";
}

/** The head a repo starts with, as the picker labels it: jj's @ of this folder's
 *  workspace, git's working tree. Stored as null. */
export const defaultHead = (repo) => (repo.kind === "jj" ? "@" : "Working tree");

/** Names the ref picker offers for the base or the head. The head list starts with its
 *  default (null) and, for jj, every workspace's working copy (`name@`). */
export async function refs(repo, which) {
  if (repo.kind === "jj") {
    const [bookmarks, workspaces] = await Promise.all([
      run(repo, "jj", ["bookmark", "list", "--all-remotes", "-T", 'name ++ if(remote, "@" ++ remote) ++ "\\n"']),
      which === "head" ? run(repo, "jj", ["workspace", "list", "-T", 'name ++ "@\\n"']).catch(() => "") : "",
    ]);
    const names = [...workspaces.split("\n"), ...bookmarks.split("\n")].filter((l) => l && !l.endsWith("@git"));
    return [which === "head" ? null : "trunk()", ...new Set(names)];
  }
  const out = await run(repo, "git", ["for-each-ref", "--format=%(refname:short)", "refs/heads", "refs/remotes", "refs/tags"]);
  const names = [...new Set(out.split("\n").filter((l) => l && !l.endsWith("/HEAD")))];
  return which === "head" ? [null, "HEAD", ...names] : names;
}

// A commit's refs as git names them: local bookmarks, remote ones as `<remote>/<name>`
// (the colocated `git` remote left out), then tags.
const JJ_REFS = 'separate(", ", local_bookmarks.map(|b| b.name()).join(", "), '
  + 'remote_bookmarks.filter(|b| b.remote() != "git").map(|b| b.remote() ++ "/" ++ b.name()).join(", "), '
  + 'tags.map(|t| t.name()).join(", "))';

const JJ_ROW = [
  "change_id", "change_id.shortest(8)", "change_id.shortest().prefix()", "commit_id.shortest(8)",
  "commit_id.shortest().prefix()", JJ_REFS, "description.first_line()",
  "committer.timestamp().ago()", "author.name()", 'if(current_working_copy, "1", "")',
].join(` ++ "${US}" ++ `) + ` ++ "${RS}"`;

function jjRows(out) {
  return out.split(RS).filter((r) => r.trim()).map((r) => {
    const [id, change, changePrefix, hash, hashPrefix, refs, desc, time, author, current] = r.replace(/^\n/, "").split(US);
    return { id, change, changePrefix, hash, hashPrefix, refs, desc, time, author, current: current === "1", worktree: false };
  });
}

const GIT_FORMAT = ["%H", "%h", "%D", "%s", "%ar", "%an"].join(US) + RS;

function gitRows(out) {
  return out.split(RS).filter((r) => r.trim()).map((r) => {
    const [id, hash, refs, desc, time, author] = r.replace(/^\n/, "").split(US);
    return { id, change: "", changePrefix: "", hash, hashPrefix: "", refs: refs.replace(/HEAD -> /, ""), desc, time, author, current: false, worktree: false };
  });
}

/** `{ above, below }`: the commits from the base (exclusive) up to the head, newest first,
 *  then the base and the 5 commits under it. `head` null is the default head; for git that
 *  adds a working-tree row on top of HEAD. */
export async function history(repo, base, head) {
  if (repo.kind === "jj") {
    const log = (revset) => run(repo, "jj", ["log", "--no-graph", "--color=never", "-r", revset, "-T", JJ_ROW]);
    const [above, below] = await Promise.all([log(`latest((${base})..(${head ?? "@"}), ${ABOVE})`), log(`ancestors(${base}, ${BELOW + 1})`)]);
    return { above: jjRows(above), below: jjRows(below) };
  }
  const log = (args) => run(repo, "git", ["log", "--no-color", `--format=${GIT_FORMAT}`, ...args]);
  const [above, below] = await Promise.all([log(["-n", String(ABOVE), `${base}..${head ?? "HEAD"}`]), log(["-n", String(BELOW + 1), base])]);
  if (head) return { above: gitRows(above), below: gitRows(below) };
  const tree = { id: "WORKTREE", change: "", changePrefix: "", hash: "", hashPrefix: "", refs: "", desc: "Working tree", time: "", author: "", current: true, worktree: true };
  return { above: [tree, ...gitRows(above)], below: gitRows(below) };
}

// The new path of a rename: "a/{b => c}/d", "{a => b}/c", "a/{b => }/c" or "a => b".
function renamed(spec) {
  const m = spec.match(/^(.*)\{(.*) => (.*)\}(.*)$/);
  const next = m ? `${m[1]}${m[3]}${m[4]}` : spec.split(" => ").pop();
  return next.replace(/\/\//g, "/");
}

/** What changed from the parent of `bottom` to `top`, both history rows. */
export function changes(repo, top, bottom) {
  if (repo.kind === "jj") return diff(repo, `${bottom.id}-`, top.id);
  return diff(repo, bottom.worktree ? "HEAD" : `${bottom.id}^`, top.worktree ? null : top.id);
}

/** What changed from the base to the head (null: the default head). This is the default
 *  diff; it does not depend on how many history rows are shown. */
export function baseDiff(repo, base, head) {
  return diff(repo, base, repo.kind === "jj" ? head ?? "@" : head);
}

// The changes between two revisions. For git, `to` null is the working tree, untracked
// files included.
async function diff(repo, from, to) {
  const out = new Map();
  if (repo.kind === "jj") {
    const text = await run(repo, "jj", ["diff", "--summary", "--color=never", "--from", from, "--to", to]);
    for (const line of text.split("\n")) {
      const kind = line[0], rest = line.slice(2);
      if (!rest) continue;
      if (kind === "R" || kind === "C") out.set(renamed(rest), "R");
      else if ("AMD".includes(kind)) out.set(rest, kind);
    }
    return out;
  }
  const text = await run(repo, "git", ["diff", "--name-status", "-M", "-z", from, ...(to ? [to] : [])]);
  const f = text.split("\0");
  for (let i = 0; i < f.length - 1;) {
    const status = f[i][0];
    if (status === "R" || status === "C") { out.set(f[i + 2], "R"); i += 3; }
    else { out.set(f[i + 1], status === "A" || status === "D" ? status : "M"); i += 2; }
  }
  if (!to) {
    const untracked = await run(repo, "git", ["ls-files", "-z", "--others", "--exclude-standard"]);
    for (const p of untracked.split("\0").filter(Boolean)) out.set(p, "A");
  }
  return out;
}

/** The full commit id a revision names (a jj revset or a git revision), the first when it
 *  names several. */
export async function commitOf(repo, rev) {
  if (repo.kind === "jj") {
    const out = await run(repo, "jj", ["log", "--no-graph", "--ignore-working-copy", "-r", rev, "-T", 'commit_id ++ "\\n"']);
    return out.split("\n")[0] || null;
  }
  return (await run(repo, "git", ["rev-parse", "--verify", `${rev}^{commit}`])).trim();
}

/** Writes `path` (relative to root) as it is in `commit` to `dest`, read-only, and empty
 *  when the commit lacks it. Reads through git, so a jj repository must be colocated. */
export async function writeFileAt(repo, commit, path, dest) {
  const script = 'mkdir -p "$(dirname "$1")" && rm -f "$1" && { git -C "$4" show "$2:$3" > "$1" 2>/dev/null || : > "$1"; } && chmod 444 "$1"';
  const r = await exec("sh", ["-c", script, "snapshot", dest, commit ?? "", path, repo.root], { on: repo.on });
  if (r.code !== 0) throw new Error((r.stderr || "snapshot failed").trim().split("\n")[0]);
}

/** Ignored paths relative to root; folders end in "/". Needs a .git (jj repos are colocated). */
export async function ignored(repo) {
  const out = await run(repo, "git", ["ls-files", "-z", "--others", "--ignored", "--exclude-standard", "--directory"]).catch(() => "");
  return new Set(out.split("\0").filter(Boolean));
}

/** One folder's entries: { name, dir }, without .git and .jj. At most 2000 per folder. */
export async function directory(repo, path) {
  const script = 'n=0; for p in "$1"/* "$1"/.[!.]* "$1"/..?*; do [ -e "$p" ] || [ -L "$p" ] || continue; name=${p##*/}; case "$name" in .git|.jj) continue;; esac; if [ -d "$p" ] && [ ! -L "$p" ]; then kind=d; else kind=f; fi; printf "%s\\0%s\\0" "$kind" "$name"; n=$((n+1)); [ "$n" -gt 2000 ] && break; done; test -d "$1"';
  const r = await exec("sh", ["-c", script, "explorer", path ? `${repo.root}/${path}` : repo.root], { on: repo.on });
  if (r.code !== 0) throw new Error(r.stderr || "Cannot list this folder");
  const fields = r.stdout.split("\0"), entries = [];
  for (let i = 0; i + 1 < fields.length; i += 2) entries.push({ name: fields[i + 1], dir: fields[i] === "d" });
  return entries;
}

/** The workspaces of the muster session the folder belongs to, as { name, path }; empty
 *  when the folder is in no session or muster is missing. */
export async function sessionProjects(folder, on) {
  const r = await exec("muster", ["ls", "--json"], { on }).catch(() => null);
  if (r?.code !== 0) return [];
  const sessions = JSON.parse(r.stdout || "[]");
  const inside = (p) => (folder + "/").startsWith(p + "/");
  const session = sessions.find((s) => s.workspaces.some((w) => inside(w.path)));
  return (session?.workspaces ?? []).filter((w) => w.state !== "missing")
    .map((w) => ({ name: w.repo.split("/").pop(), path: w.path }));
}
