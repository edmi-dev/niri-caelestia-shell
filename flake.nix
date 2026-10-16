{
  description = "Desktop shell for Caelestia dots";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    quickshell = {
      url = "git+https://git.outfoxxed.me/outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-cli = {
      url = "github:caelestia-dots/cli";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.caelestia-shell.follows = "";
    };

    m3shapes = {
      url = "github:soramanew/m3shapes/32ad9ce328bb77ed349b40a3be10ee9ea610b8ab";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    nixpkgs,
    ...
  } @ inputs: let
    inherit (nixpkgs.lib) genAttrs platforms modules lists systems;

    pkgsOf = nixpkgs.legacyPackages;
    systems' = lists.intersectLists platforms.linux systems.flakeExposed;
    eachSystem = genAttrs systems';
  in {
    formatter = eachSystem (system: pkgsOf.${system}.alejandra);

    packages = eachSystem (system: let
      pkgs = pkgsOf.${system};
    in rec {
      caelestia-shell = pkgs.callPackage ./nix {
        rev = self.rev or self.dirtyRev;
        stdenv = pkgs.clangStdenv;
        quickshell = inputs.quickshell.packages.${system}.default.override {
          withX11 = false;
          withI3 = false;
        };
        caelestia-cli = inputs.caelestia-cli.packages.${system}.default;
        m3shapes = inputs.m3shapes.packages.${system}.default;
      };
      with-cli = caelestia-shell.override {withCli = true;};
      debug = caelestia-shell.override {debug = true;};
      default = caelestia-shell;
    });

    devShells = eachSystem (system: {
      default = let
        pkgs = pkgsOf.${system};
        shell = self.packages.${system}.caelestia-shell;
        mkShell = pkgs.mkShell.override {stdenv = shell.stdenv;};
      in
        mkShell {
          inputsFrom = [shell shell.plugin shell.extras];
          packages = with pkgs; [clazy material-symbols rubik nerd-fonts.caskaydia-cove]
            # NIRI-PORT(S1): tooling for the niri port (niri msg, linters, fixture tools)
            ++ (with pkgs; [niri jq ripgrep libxml2 qt6.qtdeclarative clang-tools]);
          CAELESTIA_XKB_RULES_PATH = "${pkgs.xkeyboard-config}/share/xkeyboard-config-2/rules/base.lst";
        };
    });

    # NIRI-PORT(S1): port gate checks
    checks = eachSystem (system: let
      pkgs = pkgsOf.${system};
      inherit (pkgs) lib;
      portCheck = name: script:
        pkgs.runCommand "port-check-${name}" {nativeBuildInputs = with pkgs; [bash ripgrep findutils gnused gawk];} ''
          cp -r ${self} src && chmod -R u+w src
          PORT_ROOT="$PWD/src" bash src/scripts/port/${script}
          touch $out
        '';
    in {
      package = self.packages.${system}.caelestia-shell;
      boundary = portCheck "boundary" "check-boundary.sh";
      fhs = portCheck "fhs" "check-fhs.sh";
      # Plugin build with QtTest unit tests run against tests/fixtures/niri
      unit = self.packages.${system}.caelestia-shell.plugin.overrideAttrs (old: {
        name = "caelestia-qml-plugin-tests";
        src = lib.fileset.toSource {
          root = ./.;
          fileset = lib.fileset.unions [./CMakeLists.txt ./plugin ./tests/fixtures/niri];
        };
        cmakeFlags = old.cmakeFlags ++ [(lib.cmakeBool "CAELESTIA_BUILD_TESTS" true)];
        doCheck = true;
      });
    });

    homeManagerModules.default = modules.importApply ./nix/hm-module.nix self;
  };
}
