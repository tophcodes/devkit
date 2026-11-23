// Opens links that a terminal on another machine prints, here. A file is copied
// through herdr-core into ~/.cache/herdr-remote/<machine>/ and opened with
// xdg-open. A loopback URL opens against that machine's hostname, which the
// tailnet resolves; the dev server there has to listen on more than loopback.
// Links from local terminals pass to the next handler. Every failure shows a
// toast, so a click never ends without a visible result.
import { exec, hc, home, notify } from "herdr";

// herdr-core's machine.exec keeps the first 8 MiB of a program's output and
// drops the rest, so a larger file is refused before the copy starts.
const MAX_BYTES = 8 << 20;
// A link handler has 30 seconds to answer; the copy has to end before that.
const COPY_SECONDS = 25;

export async function handleLink({ link, source }) {
  if (!source.machine) return "pass";
  try {
    if (link.kind === "url") await openUrl(link.url, source.machine);
    else await openFile(link.raw, source);
  } catch (e) {
    notify({ title: "Remote link", body: String(e?.message ?? e), level: "error" });
  }
  return "handled";
}

async function openUrl(url, machine) {
  const listed = await hc(["machine", "ls", "--json"]);
  if (listed.code !== 0) throw new Error(`hc machine ls: ${listed.stderr.trim()}`);
  const host = JSON.parse(listed.stdout).machines.find((m) => m.name === machine)?.host;
  if (!host) throw new Error(`No machine named ${machine}`);
  await open(url.replace(/^(https?:\/\/)(\[::1\]|[^/:]+)/, `$1${host}`));
}

async function openFile(raw, source) {
  const { machine, cwd } = source;
  const path = decodeURIComponent(raw.replace(/^file:\/\/[^/]*/, "")).replace(/(:\d+){1,2}$/, "");

  // One remote call resolves the path and reads its size and type.
  const probe = await exec("sh", ["-c", 'realpath -e -- "$1" && stat -L -c "%s %F" -- "$1"', "sh", path], {
    on: machine,
    cwd: path.startsWith("/") ? undefined : cwd ?? undefined,
  });
  if (probe.code !== 0) throw new Error(`${machine}:${path}: ${probe.stderr.trim()}`);
  const [abs, stat] = probe.stdout.trim().split("\n");
  const [size, ...type] = stat.split(" ");
  if (type.join(" ") !== "regular file") throw new Error(`${machine}:${abs} is a ${type.join(" ")}`);
  if (Number(size) > MAX_BYTES) {
    throw new Error(`${machine}:${abs} has ${mib(size)} MiB; herdr-core copies at most ${mib(MAX_BYTES)} MiB`);
  }

  const local = `${home()}/.cache/herdr-remote/${machine}${abs}`;
  const copy = await exec(
    "sh",
    [
      "-c",
      'mkdir -p -- "$(dirname -- "$4")" && hc exec --timeout "$1" --on "$2" -- cat -- "$3" >"$4.part" && mv -- "$4.part" "$4"',
      "sh",
      String(COPY_SECONDS),
      machine,
      abs,
      local,
    ],
    { timeout: (COPY_SECONDS + 3) * 1000 },
  );
  if (copy.code !== 0 || copy.stderr.includes("[hc]")) {
    throw new Error(`Copy of ${machine}:${abs} failed: ${copy.stderr.trim() || `exit ${copy.code}`}`);
  }
  await open(local);
}

async function open(target) {
  const r = await exec("xdg-open", [target], { timeout: 10000 });
  if (r.code !== 0) throw new Error(`xdg-open ${target}: ${r.stderr.trim() || `exit ${r.code}`}`);
}

const mib = (bytes) => (Number(bytes) / (1 << 20)).toFixed(1);
