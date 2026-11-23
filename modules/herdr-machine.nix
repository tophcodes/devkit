# NixOS module for a machine the herdr workbench's tabs run on (herdr/ in this
# repository). The mods run hx, jj and git there through herdr-core, so this
# installs them, with the Helix from overlays.helix. Every Claude Code session
# on the machine reports to herdr-core through claude-herdr-status, from a
# managed settings drop-in. With `devkit.herdr.core.users` set, a user unit
# starts each listed user's core at boot.
#
# The workbench's remote-links mod opens a loopback URL from a terminal here
# against this machine's tailnet hostname. `devkit.herdr.devPorts` opens a port
# range on tailscale0 for that, and the managed CLAUDE.md tells every Claude
# Code session here to serve on that range and to print paths and URLs the mod
# can open.
{localInputs}: {
  config,
  lib,
  pkgs,
  ...
}: let
  packages = localInputs.self.packages.${pkgs.stdenv.hostPlatform.system};
  cfg = config.devkit.herdr.core;
  ports = config.devkit.herdr.devPorts;
in {
  options.devkit.herdr.devPorts = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule {
      options = {
        from = lib.mkOption {type = lib.types.port;};
        to = lib.mkOption {type = lib.types.port;};
      };
    });
    default = {
      from = 3000;
      to = 9999;
    };
    description = ''
      TCP ports open on tailscale0 for dev servers that agents start here.
      Null opens none and leaves the managed CLAUDE.md out.
    '';
  };

  options.devkit.herdr.core = {
    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = null;
      description = "herdr-core, which provides `hc`. Required when `users` is set.";
    };
    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = ''
        Users that run their own core from boot, so kept terminals get their
        shells back without waiting for the first connection. They linger, since
        the core runs as its own transient unit.
      '';
    };
  };

  config = lib.mkMerge [
    {
      environment.systemPackages = [packages.helix pkgs.jujutsu pkgs.git];

      environment.etc."claude-code/managed-settings.d/60-herdr.json".text = builtins.toJSON {
        inherit (packages.claude-herdr-status) hooks;
      };
    }

    (lib.mkIf (ports != null) {
      networking.firewall.interfaces.tailscale0.allowedTCPPortRanges = [ports];

      environment.etc."claude-code/CLAUDE.md".text = ''
        # Showing work to Toph

        Toph often watches this machine from another one, through the herdr
        window. Ctrl-clicking a path or a localhost URL in a terminal opens it
        there, so print things in a form that click can follow:

        - A dev server listens on all interfaces (`0.0.0.0`) on a port from
          ${toString ports.from} to ${toString ports.to}, for example `vite --host 0.0.0.0`
          or `rails s -b 0.0.0.0`. Print its URL as `http://localhost:<port>`.
          The firewall blocks other ports from the tailnet.
        - A file meant for Toph (a screenshot, a report, a build artifact) gets
          printed as its absolute path on a line of its own. Files above 8 MiB
          do not transfer; say so and offer a smaller form.
      '';
    })

    (lib.mkIf (cfg.users != []) {
      assertions = [
        {
          assertion = cfg.package != null;
          message = "devkit.herdr.core.users needs devkit.herdr.core.package.";
        }
      ];

      environment.systemPackages = [cfg.package];
      users.users = lib.genAttrs cfg.users (_: {linger = true;});

      # The core passes its environment to every command it starts by argv,
      # such as the mods' hx, jj and git, so it starts from a login shell: a
      # service's own PATH holds only coreutils, findutils, grep, sed and
      # systemd. NixOS installs user units for every user; the `|` prefix ORs
      # the conditions, so only the listed users run it.
      systemd.user.services.herdr-core = {
        description = "Start herdr-core";
        wantedBy = ["default.target"];
        unitConfig.ConditionUser = map (u: "|${u}") cfg.users;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.bash}/bin/bash -l -c '${cfg.package}/bin/hc server start'";
        };
      };
    })
  ];
}
