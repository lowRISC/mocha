// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
#include <cassert>
#include <fstream>
#include <iostream>

#include "Vtop_chip_verilator__Syms.h"
#include "verilated_toplevel.h"
#include "verilator_memutil.h"
#include "verilator_sim_ctrl.h"

class MochaSim {
 public:
  MochaSim(const char *sram_hier_path, int sram_size_words,
           const char *dram_hier_path, int dram_size_words,
           const char *rom_hier_path,  int rom_size_words);
  virtual ~MochaSim() {}
  virtual int Main(int argc, char **argv);


 protected:
  top_chip_verilator _top;
  VerilatorMemUtil _memutil;
  MemArea _sram, _dram, _rom;

  virtual int Setup(int argc, char **argv, bool &exit_app);
  virtual void Run();
  virtual bool Finish();
};

MochaSim::MochaSim(const char *sram_hier_path, int sram_size_words,
                   const char *dram_hier_path, int dram_size_words,
                   const char *rom_hier_path,  int rom_size_words)
    : _sram(sram_hier_path, sram_size_words, 8),
      _dram(dram_hier_path, dram_size_words, 8),
      _rom(rom_hier_path, rom_size_words, 4) {}

int MochaSim::Main(int argc, char **argv) {
  bool exit_app;
  int ret_code = Setup(argc, argv, exit_app);

  if (exit_app) {
    return ret_code;
  }

  Run();

  if (!Finish()) {
    return 1;
  }

  return 0;
}

int MochaSim::Setup(int argc, char **argv, bool &exit_app) {
  VerilatorSimCtrl &simctrl = VerilatorSimCtrl::GetInstance();

  simctrl.SetTop(&_top, &_top.clk_i, &_top.rst_ni,
                 VerilatorSimCtrlFlags::ResetPolarityNegative);

  _memutil.RegisterMemoryArea("sram", 0x10000000, &_sram);
  _memutil.RegisterMemoryArea("dram", 0x80000000, &_dram);
  _memutil.RegisterMemoryArea("rom", 0x00080000, &_rom);
  simctrl.RegisterExtension(&_memutil);

  exit_app = false;
  return simctrl.ParseCommandArgs(argc, argv, exit_app);
}

void MochaSim::Run() {
  VerilatorSimCtrl &simctrl = VerilatorSimCtrl::GetInstance();

  std::cout << "Simulation of CHERI Mocha" << std::endl
            << "=========================" << std::endl
            << std::endl;

  simctrl.RunSimulation();
}

bool MochaSim::Finish() {
  VerilatorSimCtrl &simctrl = VerilatorSimCtrl::GetInstance();

  if (!simctrl.WasSimulationSuccessful()) {
    return false;
  }

  svSetScope(svGetScopeFromName("TOP.top_chip_verilator"));

  return true;
}

int main(int argc, char **argv) {
  MochaSim mocha_sim(
      "TOP.top_chip_verilator.u_top_chip_system.u_axi_sram.u_ram",
      16 * 1024, // 16k 64-bit words = 128 KiB
      "TOP.top_chip_verilator.u_dram_wrapper.u_ext_mem",
      2 * 1024 * 1024, // = 2 GiB
      "TOP.top_chip_verilator.u_top_chip_system.u_rom_ctrl.gen_rom_scramble_disabled.u_rom.u_prim_rom",
      8 * 1024 // = 8KiB
  );

  return mocha_sim.Main(argc, argv);
}
