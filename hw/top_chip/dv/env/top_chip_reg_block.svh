// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// Register model of the chip as CVA6 addresses it
//
// The model holds one register block per xbar_peri device, at the base address that xbar_peri
// decodes for that device, so an access through the model takes the same path through the AXI
// crossbar and xbar_peri as a CVA6 load or store. The base addresses come from tl_peri_pkg, which
// tlgen generates from the same description as the xbar_peri RTL.
//
// Mocha's top has no topgen description, so nothing generates this model the way topgen does for
// an OpenTitan top. build() follows what topgen's top_uvm_reg.sv.tpl would produce, including the
// backdoor root of each block, which names the block's instance in top_chip_system. Reading a
// register through the backdoor therefore shows which instance a frontdoor access reached.
class top_chip_reg_block extends dv_base_reg_block;
  `uvm_object_utils(top_chip_reg_block)

  // One register block per xbar_peri device, named after its IP block. rom_ctrl's name also carries
  // the interface, as topgen names it.
  clkmgr_reg_block        clkmgr;
  entropy_src_reg_block   entropy_src;
  gpio_reg_block          gpio;
  i2c_reg_block           i2c;
  pwrmgr_reg_block        pwrmgr;
  rom_ctrl_regs_reg_block rom_ctrl_regs;
  rstmgr_reg_block        rstmgr;
  rv_plic_reg_block       rv_plic;
  rv_timer_reg_block      rv_timer;
  spi_device_reg_block    spi_device;
  spi_host_reg_block      spi_host;
  uart_reg_block          uart;

  // Standard SV/UVM methods
  extern function new(string name = "", int has_coverage = UVM_NO_COVERAGE);

  // Methods extending base methods from dv_base_reg_block

  // Create the default map, then build each xbar_peri device's block at its base address
  extern virtual function void build(uvm_reg_addr_t base_addr, csr_excl_item csr_excl = null);

  // Class specific methods

  // Build one device's register block and add its map to the default map
  //
  //    blk:       The device's register block, already created
  //    inst_name: The device's instance name in top_chip_system, without the u_ prefix
  //    addr:      The device's base address in the default map
  //    csr_excl:  The exclusions object shared by every block in the model
  extern local function void add_block(dv_base_reg_block blk,
                                       string            inst_name,
                                       uvm_reg_addr_t    addr,
                                       csr_excl_item     csr_excl);
endclass : top_chip_reg_block


function top_chip_reg_block::new(string name = "", int has_coverage = UVM_NO_COVERAGE);
  super.new(name, has_coverage);
endfunction : new

function void top_chip_reg_block::build(uvm_reg_addr_t base_addr, csr_excl_item csr_excl = null);
  // Every register is one TL-UL word wide. The AXI register layer puts each access on the right
  // byte lanes of the wider AXI bus.
  default_map = create_map(.name("default_map"), .base_addr(base_addr), .n_bytes(TL_DW / 8),
                           .endian(UVM_LITTLE_ENDIAN));
  if (csr_excl == null) begin
    csr_excl = csr_excl_item::type_id::create("csr_excl");
    this.csr_excl = csr_excl;
  end

  clkmgr = clkmgr_reg_block::type_id::create("clkmgr");
  add_block(clkmgr, "clkmgr", base_addr + ADDR_SPACE_CLKMGR, csr_excl);

  entropy_src = entropy_src_reg_block::type_id::create("entropy_src");
  add_block(entropy_src, "entropy_src", base_addr + ADDR_SPACE_ENTROPY_SRC, csr_excl);

  gpio = gpio_reg_block::type_id::create("gpio");
  add_block(gpio, "gpio", base_addr + ADDR_SPACE_GPIO, csr_excl);

  i2c = i2c_reg_block::type_id::create("i2c");
  add_block(i2c, "i2c", base_addr + ADDR_SPACE_I2C, csr_excl);

  pwrmgr = pwrmgr_reg_block::type_id::create("pwrmgr");
  add_block(pwrmgr, "pwrmgr", base_addr + ADDR_SPACE_PWRMGR, csr_excl);

  rom_ctrl_regs = rom_ctrl_regs_reg_block::type_id::create("rom_ctrl_regs");
  add_block(rom_ctrl_regs, "rom_ctrl", base_addr + ADDR_SPACE_ROM_CTRL_REGS, csr_excl);

  rstmgr = rstmgr_reg_block::type_id::create("rstmgr");
  add_block(rstmgr, "rstmgr", base_addr + ADDR_SPACE_RSTMGR, csr_excl);

  rv_plic = rv_plic_reg_block::type_id::create("rv_plic");
  add_block(rv_plic, "rv_plic", base_addr + ADDR_SPACE_PLIC, csr_excl);

  rv_timer = rv_timer_reg_block::type_id::create("rv_timer");
  add_block(rv_timer, "timer", base_addr + ADDR_SPACE_TIMER, csr_excl);

  spi_device = spi_device_reg_block::type_id::create("spi_device");
  add_block(spi_device, "spi_device", base_addr + ADDR_SPACE_SPI_DEVICE, csr_excl);

  spi_host = spi_host_reg_block::type_id::create("spi_host");
  add_block(spi_host, "spi_host", base_addr + ADDR_SPACE_SPI_HOST, csr_excl);

  uart = uart_reg_block::type_id::create("uart");
  add_block(uart, "uart", base_addr + ADDR_SPACE_UART, csr_excl);
endfunction : build

function void top_chip_reg_block::add_block(dv_base_reg_block blk,
                                            string            inst_name,
                                            uvm_reg_addr_t    addr,
                                            csr_excl_item     csr_excl);
  // The generated blocks root their backdoor paths at tb.dut. Each one is moved down to its own
  // instance, for the two path kinds the generated register classes use.
  string hdl_path = {"tb.dut.u_", inst_name};

  // A shadowed register names its alerts after the block's ip_name, and get_ip_name() fails when
  // the name has not been set
  blk.set_ip_name(inst_name);
  blk.configure(.parent(this));
  blk.build(.base_addr(addr), .csr_excl(csr_excl));
  blk.set_hdl_path_root(hdl_path, "BkdrRegPathRtl");
  blk.set_hdl_path_root(hdl_path, "BkdrRegPathRtlShadow");
  default_map.add_submap(.child_map(blk.default_map), .offset(addr));
endfunction : add_block
