# Claude Code's status line: session title, model and context, where the work
# stands in jj or git, and the references the agent filed on its erker session.
# A machine points `statusLine.command` in its Claude Code settings at
# `bin/claude-statusline`.
{pkgs, ...}:
pkgs.writeShellApplication {
  name = "claude-statusline";
  runtimeInputs = [pkgs.jq pkgs.git pkgs.gnused pkgs.gnugrep];
  text = builtins.readFile ./statusline.sh;
}
