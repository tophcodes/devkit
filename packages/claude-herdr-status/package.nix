# The Claude Code hook script that reports a session's state to herdr-core and
# labels its terminal with the repositories the session works in. A machine
# registers `bin/claude-herdr-status <state> [kind]` as the command of its
# Claude Code hooks.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "claude-herdr-status";
  runtimeInputs = [pkgs.coreutils pkgs.procps pkgs.jq pkgs.git pkgs.gawk];
  text = builtins.readFile ./status.sh;
}
