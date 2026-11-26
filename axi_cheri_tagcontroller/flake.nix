{
  description = "CHERI tag controller";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
  };

  outputs = inputs@{ self, nixpkgs, flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [ "x86_64-linux" ];

      perSystem = { config, pkgs, system, ... }: {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            gtest
            bender
            verilator
          ];

          GREETING = "cheri tag controller devshell";
          RISCV = "NOT_IN_USE";
          shellHook = ''
            echo "$GREETING"
          '';
        };
      };
    };
}
