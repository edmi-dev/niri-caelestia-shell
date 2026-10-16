self: {
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (pkgs.stdenv.hostPlatform) system;

  cli-default = self.inputs.caelestia-cli.packages.${system}.default;
  shell-default = self.packages.${system}.with-cli;

  cfg = config.programs.caelestia;
in {
  imports = [
    (lib.mkRenamedOptionModule ["programs" "caelestia" "environment"] ["programs" "caelestia" "systemd" "environment"])
  ];
  options = with lib; {
    programs.caelestia = {
      enable = mkEnableOption "Enable Caelestia shell";
      package = mkOption {
        type = types.package;
        default = shell-default;
        description = "The package of Caelestia shell";
      };
      systemd = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Enable the systemd service for Caelestia shell";
        };
        target = mkOption {
          type = types.str;
          description = ''
            The systemd target that will automatically start the Caelestia shell.
          '';
          default = config.wayland.systemd.target;
        };
        environment = mkOption {
          type = types.listOf types.str;
          description = "Extra Environment variables to pass to the Caelestia shell systemd service.";
          default = [];
          example = [
            "QT_QPA_PLATFORMTHEME=gtk3"
          ];
        };
      };
      settings = mkOption {
        type = types.attrsOf types.anything;
        default = {};
        description = "Caelestia shell settings";
      };
      extraConfig = mkOption {
        type = types.str;
        default = "";
        description = "Caelestia shell extra configs written to shell.json";
      };
      # NIRI-PORT(Q-NIX1): "managed" keeps shell.json a read-only store symlink (settings only from Nix);
      # "seed" copies it once when missing so the shell's own settings UI can save changes
      settingsMode = mkOption {
        type = types.enum ["managed" "seed"];
        default = "managed";
        description = ''
          How shell.json is installed. "managed": a read-only symlink regenerated from `settings`/`extraConfig`.
          "seed": a writable copy created only when the file is missing (or is a leftover store symlink);
          later changes to `settings` do not apply until the file is removed.
        '';
      };
      # NIRI-PORT(Q-NIX2): niri config snippet (binds, layer rule, game mode include) for `include "caelestia.kdl"`
      niri = {
        enable = mkEnableOption "writing ~/.config/niri/caelestia.kdl; add `include \"caelestia.kdl\"` at the end of your niri config";
        config = mkOption {
          type = types.lines;
          default = builtins.readFile ./niri/caelestia.kdl;
          defaultText = literalExpression "builtins.readFile ./niri/caelestia.kdl";
          description = "Contents of caelestia.kdl. `caelestia-shell` in spawn commands is replaced by the package's binary.";
        };
      };
      cli = {
        enable = mkEnableOption "Enable Caelestia CLI";
        package = mkOption {
          type = types.package;
          default = cli-default;
          description = "The package of Caelestia CLI"; # Doesn't override the shell's CLI, only change from home.packages
        };
        settings = mkOption {
          type = types.attrsOf types.anything;
          default = {};
          description = "Caelestia CLI settings";
        };
        extraConfig = mkOption {
          type = types.str;
          default = "";
          description = "Caelestia CLI extra configs written to cli.json";
        };
      };
    };
  };

  config = let
    cli = cfg.cli.package;
    shell = cfg.package;
    mkConfig = c:
      lib.pipe (
        if c.extraConfig != ""
        then c.extraConfig
        else "{}"
      ) [
        builtins.fromJSON
        (lib.recursiveUpdate c.settings)
        builtins.toJSON
      ];
    shouldGenerate = c: c.extraConfig != "" || c.settings != {};
  in
    lib.mkIf cfg.enable {
      systemd.user.services.caelestia = lib.mkIf cfg.systemd.enable {
        Unit = {
          Description = "Caelestia Shell Service";
          After = [cfg.systemd.target];
          PartOf = [cfg.systemd.target];
          X-Restart-Triggers = lib.mkIf (cfg.settings != {} && cfg.settingsMode == "managed") [
            "${config.xdg.configFile."caelestia/shell.json".source}"
          ];
        };

        Service = {
          Type = "exec";
          ExecStart = "${shell}/bin/caelestia-shell";
          Restart = "on-failure";
          RestartSec = "5s";
          TimeoutStopSec = "5s";
          Environment =
            [
              "QT_QPA_PLATFORM=wayland"
            ]
            ++ cfg.systemd.environment;

          Slice = "session.slice";
        };

        Install = {
          WantedBy = [cfg.systemd.target];
        };
      };

      xdg.configFile = {
        "caelestia/shell.json" = lib.mkIf (shouldGenerate cfg && cfg.settingsMode == "managed") {
          text = mkConfig cfg;
        };
        "caelestia/cli.json" = lib.mkIf (shouldGenerate cfg.cli) {
          text = mkConfig cfg.cli;
        };
        # Absolute binary path, so IPC calls reach the instance started from this package
        "niri/caelestia.kdl" = lib.mkIf cfg.niri.enable {
          text = builtins.replaceStrings [''spawn "caelestia-shell"''] [''spawn "${shell}/bin/caelestia-shell"''] cfg.niri.config;
        };
      };

      # NIRI-PORT(Q-NIX1): seed a writable shell.json; replace a leftover read-only symlink from "managed" mode
      home.activation.caelestiaSeedSettings = lib.mkIf (cfg.settingsMode == "seed" && shouldGenerate cfg) (lib.hm.dag.entryAfter ["linkGeneration"] ''
        target="${config.xdg.configHome}/caelestia/shell.json"
        if [ -L "$target" ] && [[ "$(readlink "$target")" == /nix/store/* ]]; then
          run rm $VERBOSE_ARG "$target"
        fi
        if [ ! -e "$target" ]; then
          run install $VERBOSE_ARG -Dm644 ${pkgs.writeText "caelestia-shell.json" (mkConfig cfg)} "$target"
        fi
      '');

      home.packages = [shell] ++ lib.optional cfg.cli.enable cli;
    };
}
