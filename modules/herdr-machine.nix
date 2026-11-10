# NixOS module for a machine the herdr workbench's tabs run on (herdr/ in this
# repository). The mods run hx, jj and git there through herdr-core, so this
# installs them, with the Helix from overlays.helix. Every Claude Code session
# on the machine reports to herdr-core through claude-herdr-status, from a
# managed settings drop-in. With `devkit.herdr.core.users` set, a user unit
# starts each listed user's core at boot.
{localInputs}: {
  config,
  lib,
  pkgs,
  ...
}: let
  packages = localInputs.self.packages.${pkgs.stdenv.hostPlatform.system};
  cfg = config.devkit.herdr.core;
in {
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
