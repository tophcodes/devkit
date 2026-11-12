---
name: popup-terminal
description: Run a command that asks for input on a terminal (a PIN, a password, sudo, an SSH host-key question, a `read` prompt, `agenix rekey` with a YubiKey) through `pt`, which opens it in a herdr popup Toph answers. Use before running such a command from the Bash tool, and when a command failed with "no tty", "inappropriate ioctl for device", "a terminal is required" or a pinentry error.
---

# Commands that ask Toph something

The Bash tool runs without a terminal. A command that prompts on the terminal
fails there: pinentry-curses for the YubiKey PIN (`agenix rekey`), sudo, an SSH
host-key question, `read` in a script.

When the session runs in hc (`HC_TERMINAL_ID` is set), run such a command with
`pt`, the same command Toph types as `! pt <cmd>`. It runs the command through
`hc run` in a child terminal with its own tty, herdr-app shows that terminal to
Toph as a popup, Toph answers there, and `pt` returns the exit code and the
output:

```sh
pt --name rekey just rekey
```

- `pt` waits up to 30 minutes, longer than a Bash tool call may take. Run a long
  command with `run_in_background` and act on the completion notice.
- hc options go before the command. `--name` makes it addressable: `hc wait <name>`
  waits again, `hc read <name>` prints the screen.
- Output of full-screen programs (`less`, `vim`) does not come back, and neither
  does hidden input, so a PIN or password never enters the conversation.
- Without hc, hand the command to Toph instead.
