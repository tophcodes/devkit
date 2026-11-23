# The Claude Code skills OpenSpec installs, one directory per skill. `openspec
# init` writes them into a scratch repository at build time, so they always
# match the openspec in the dev shell.
# openspec 1.x writes the skills elsewhere and with a different command set.
{pkgs, ...}:
assert pkgs.lib.assertMsg (pkgs.lib.versionAtLeast pkgs.openspec.version "2.0") "openspec-skills needs openspec 2.0 or later, nixpkgs has ${pkgs.openspec.version}";
  pkgs.runCommand "openspec-skills-${pkgs.openspec.version}" {
    nativeBuildInputs = [pkgs.openspec];
    DO_NOT_TRACK = "1";
  } ''
    export HOME=$TMPDIR
    mkdir repo && cd repo
    # Nix gives the builder a pseudo-terminal; openspec then animates a spinner
    # that never ends. Redirected output makes it run non-interactively.
    openspec init --tools claude > $TMPDIR/init.log 2>&1 < /dev/null || { cat $TMPDIR/init.log; exit 1; }
    cp -r .agents/skills $out
    rm $out/.openspec-target
  ''
