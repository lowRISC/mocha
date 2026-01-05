# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
{
  description = "CHERI-Mocha is a secure enclave reference design and is part of the COSMIC project.";
  inputs = {
    lowrisc-nix.url = "github:lowRISC/lowrisc-nix";

    nixpkgs.follows = "lowrisc-nix/nixpkgs";
    flake-utils.follows = "lowrisc-nix/flake-utils";
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
    };
  };

  nixConfig = {
    extra-substituters = ["https://nix-cache.lowrisc.org/public/"];
    extra-trusted-public-keys = ["nix-cache.lowrisc.org-public-1:O6JLD0yXzaJDPiQW1meVu32JIDViuaPtGDfjlOopU7o="];
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    lowrisc-nix,
    ...
  } @ inputs: let
    system_outputs = system: let
      pkgs = import nixpkgs {inherit system;};
      lrPkgs = lowrisc-nix.outputs.packages.${system};

      workspace = inputs.uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./.;};
      overlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };

      pythonSet =
        (pkgs.callPackage inputs.pyproject-nix.build.packages {
          python = pkgs.python310;
        }).overrideScope
        (
          pkgs.lib.composeManyExtensions [
            inputs.pyproject-build-systems.overlays.default
            overlay
            (lowrisc-nix.lib.pyprojectOverrides {inherit pkgs;})
          ]
        );

      pythonEnv = pythonSet.mkVirtualEnv "python-env" workspace.deps.default;

      commonPackages = with pkgs; [
        cmake
        gnumake
        screen
        picocom
        gtkwave
        openfpgaloader
        openocd
        uv
        pythonEnv
        verilator
        srecord
      ];
    in {
      formatter = pkgs.alejandra;
      devShells = rec {
        default = cheri;
        cheri = pkgs.mkShell {
          name = "mocha-cheri";
          nativeBuildInputs =
            commonPackages
            ++ (with lrPkgs; [
              llvm_cheri
            ]);
          buildInputs = with pkgs; [libelf zlib];
          env = {
            # Prevent uv from managing Python downloads
            UV_PYTHON_DOWNLOADS = "never";
            # Force uv to use nixpkgs Python interpreter
            UV_PYTHON = pythonSet.python.interpreter;
          };
        };
        legacy = pkgs.mkShell {
          name = "mocha-legacy";
          nativeBuildInputs =
            commonPackages
            ++ (with pkgs; [
              clang_18
              llvmPackages_18.llvm
            ]);
          buildInputs = with pkgs; [libelf zlib];
        };
      };
    };
  in
    flake-utils.lib.eachDefaultSystem system_outputs;
}
