# The Claude Code hook script that reports a session's state to herdr-core and
# labels its terminal with the repositories the session works in. A machine
# registers `bin/claude-herdr-status <state> [kind]` as the command of its
# Claude Code hooks; `passthru.hooks` holds them as the `hooks` value of a
# Claude Code settings file.
{pkgs, ...}: let
  bin = "${status}/bin/claude-herdr-status";

  # Stop reports `done`; herdr-app turns it into `idle` once the session is
  # looked at. PostToolUse clears `blocked` after a permission was granted.
  hook = args: extra: [
    ({
        hooks = [
          {
            type = "command";
            command = "${bin} ${args}";
          }
        ];
      }
      // extra)
  ];
  hooks = {
    SessionStart = hook "idle" {};
    UserPromptSubmit = hook "working" {};
    PostToolUse = hook "working" {};
    Notification =
      hook "blocked permission" {matcher = "permission_prompt";}
      ++ hook "blocked question" {matcher = "elicitation_dialog";};
    Stop = hook "done" {};
    SessionEnd = hook "clear" {};
  };

  status = pkgs.writeShellApplication {
    name = "claude-herdr-status";
    runtimeInputs = [pkgs.coreutils pkgs.procps pkgs.jq pkgs.git pkgs.gawk];
    text = builtins.readFile ./status.sh;
    passthru = {inherit hooks;};
  };
in
  status
