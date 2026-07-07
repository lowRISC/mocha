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
    ftditool = {
      url = "github:lowRISC/ftditool?ref=v0.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixConfig = {
    extra-substituters = ["https://nix-cache.lowrisc.org/public/"];
    extra-trusted-public-keys = ["nix-cache.lowrisc.org-public-1:O6JLD0yXzaJDPiQW1meVu32JIDViuaPtGDfjlOopU7o="];
  };

  outputs = {
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
          python = pkgs.python312;
        }).overrideScope
        (
          pkgs.lib.composeManyExtensions [
            inputs.pyproject-build-systems.overlays.default
            overlay
            (lowrisc-nix.lib.pyprojectOverrides {inherit pkgs;})
          ]
        );

      pythonEnv = pythonSet.mkVirtualEnv "python-env" workspace.deps.default;

      fpga = import nix/fpga.nix {
        inherit
          pkgs
          pythonEnv
          ;
        llvm = lrPkgs.llvm_cheri;
        ftditool = ftditool-cli;
      };
      ftditool-cli = inputs.ftditool.packages.${system}.default;
      cheri-toolchain = pkgs.callPackage ./nix/cheri_toolchain.nix {inherit (lrPkgs) llvm_cheri;};
    in {
      formatter = pkgs.alejandra;
      devShells = rec {
        default = baremetal;
        # CHERI baremetal + EDA development shell, built on lowrisc-nix's generic
        # mkEdaShell. Commercial EDA tools (Xcelium, Jasper, Vivado) are declared
        # via tool_data.json and resolved at runtime from the JSON file named by
        # $LOWRISC_EDA_CONFIG; without that config the shell still works and just
        # warns. Open-source tools listed in tool_data.json (Verilator, FuseSoC)
        # are absent from that config and are simply skipped — they are still
        # provided as Nix packages below. Enter with `nix develop`; it execs a
        # hermetic FHS sandbox, so it is not direnv-loadable.
        baremetal = lowrisc-nix.lib.mkEdaShell {
          inherit pkgs;
          name = "baremetal";
          tools = builtins.fromJSON (builtins.readFile ./tool_data.json);
          extraDeps =
            (with pkgs; [
              bc
              bison
              cmake
              cpio
              flex
              gnumake
              picocom
              gtkwave
              openfpgaloader
              ftditool-cli
              openocd
              gdb
              expect
              uv
              pythonEnv
              verible
              srecord
              d2
              dtc
              autoconf
              automake
              bmake
              byacc
              libarchive
              libarchive.dev
              libelf
              libtool
              pkg-config
              zlib
              zlib.dev
            ])
            ++ (with lrPkgs; [
              verilator_5_040
              llvm_cheri
            ]);
          # Project env, appended after the EDA setup (mkEdaShell has no `env`
          # attr — buildFHSEnv takes a bash profile fragment instead).
          profile = ''
            # Prevent uv from managing Python downloads; force the nixpkgs interpreter.
            export UV_PYTHON_DOWNLOADS=never
            export UV_PYTHON=${pythonSet.python.interpreter}

            export SYSROOT_PURECAP=${cheri-toolchain.linux-headers-purecap}/usr/include
            export COMPILER_RT_PURECAP=${cheri-toolchain.compiler-rt-builtins-purecap}/lib
            export LIBC_PURECAP_INCLUDE=${cheri-toolchain.muslc-linux-riscv64-purecap}/include
            export LIBC_PURECAP_LIB=${cheri-toolchain.muslc-linux-riscv64-purecap}/lib

            export HOSTCC=${pkgs.llvmPackages_21.clang}/bin/clang
            export HOSTCXX=${pkgs.llvmPackages_21.clang}/bin/clang++
            export HOSTLD=${pkgs.llvmPackages_21.lld}/bin/ld.lld
          '';
        };
      };

      apps = {
        bitstream-build = flake-utils.lib.mkApp {
          drv = fpga.bitstream-build;
        };
        bitstream-hash = flake-utils.lib.mkApp {
          drv = fpga.bitstream-hash;
        };
        bitstream-load = flake-utils.lib.mkApp {
          drv = fpga.bitstream-load;
        };
        fpga-runner = flake-utils.lib.mkApp {
          drv = fpga.fpga-runner;
        };
      };
    };
  in
    flake-utils.lib.eachDefaultSystem system_outputs;
}
