# Copyright lowRISC contributors.
# Licensed under the Apache License, Version 2.0, see LICENSE for details.
# SPDX-License-Identifier: Apache-2.0
{
  pkgs,
  pythonEnv,
  llvm
}: let
  inherit (pkgs.lib) fileset;

  bitstreamFileset = fileset.unions [
    ../hw
  ];

  bitstreamSource = fileset.toSource {
    root = ../.;
    fileset = bitstreamFileset;
  };
in {
  # The only files we expect the fpga build depends.
  bitstreamDependancies = fileset.toSource {
    root = ../.;
    fileset = fileset.unions [
      bitstreamFileset
    ];
  };

  bitstream-build = pkgs.writeShellApplication {
    name = "bitstream-build";
    runtimeInputs = [pythonEnv llvm pkgs.gnumake pkgs.cmake pkgs.srecord];
    text = ''
      cmake -B build/sw -S sw
      cmake --build build/sw --target hello_world

      fusesoc --cores-root=${bitstreamSource} \
        run --target=synth lowrisc:mocha:chip_mocha_genesys2 \
        --BootRomInitFile=build/sw/device/examples/hello_world/hello_world.vmem
    '';
  };

  bitstream-load = pkgs.writeShellApplication {
    name = "bitstream-load";
    runtimeInputs = [pkgs.openfpgaloader];
    text = ''
      openFPGALoader -b genesys2 build/lowrisc_mocha_chip_mocha_genesys2_0/synth-vivado/lowrisc_mocha_chip_mocha_genesys2_0.bit
    '';
  };

}
