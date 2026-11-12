#!/usr/bin/env bash
# pt: run a command in a popup terminal.
#
# hc starts the command in a child terminal with its own tty, which herdr-app
# shows as a popup, and waits for it like a shell. In Claude Code, `! pt <cmd>`
# is `! <cmd>` for commands that ask for input: a PIN, a password, a prompt.
#
# hc options go before the command: `pt --name rekey just rekey`.
if [ $# -eq 0 ]; then
  echo "usage: pt [hc run options] <command> [args...]" >&2
  exit 2
fi

opts=()
while [ $# -gt 0 ]; do
  case $1 in
    --name | --cwd | --on | --label | --parent | --timeout)
      opts+=("$1" "$2")
      shift 2
      ;;
    --*)
      opts+=("$1")
      shift
      ;;
    *) break ;;
  esac
done

# The child terminal takes its environment from herdr-app, which holds the
# desktop's display. The pinentry wrapper picks pinentry-qt whenever a display
# is set, and a Qt dialog is no prompt in the popup. Without both variables it
# picks pinentry-curses on the popup's tty.
#
# hc run returns after --timeout seconds and leaves the command running; 30
# minutes covers a full `agenix rekey` with a touch per secret.
exec hc run --timeout 1800 "${opts[@]}" env -u WAYLAND_DISPLAY -u DISPLAY "$@"
