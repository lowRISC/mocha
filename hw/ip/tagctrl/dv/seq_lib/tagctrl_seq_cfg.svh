// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

  typedef enum {WalkNone, WalkRead, WalkWriteRead} tagctrl_walk_e;

  typedef enum {CfgScopeAll, CfgScopeRegion, CfgScopeStatus} tagctrl_cfg_scope_e;

  // The knobs of a run, randomised once per seed by the test and read by tagctrl_main_vseq. A test
  // narrows them by overriding this class with one that adds constraints.
  class tagctrl_seq_cfg extends uvm_object;

    localparam int unsigned MaxOps = 40;

    // Zeroing time grows with the covered region, so keep it to a size a test can wait for
    localparam bit [63:0] MaxCoveredBytes = 64'h400_0000;

    // Program the region registers with the values below and start, before the random accesses
    rand bit configure;

    // The baseline region layout of the vPlan
    rand bit baseline_cfg;

    rand bit [63:0] covered_base;
    rand bit [63:0] covered_top;
    rand bit [63:0] tag_table_base;

    // Walk the register map before anything else: read every register, the performance
    // registers and the reserved space, or read, write and read again each register
    rand tagctrl_walk_e walk;

    // Random accesses after the walk and the configuration
    rand int unsigned num_ops;

    // Relative weights of accesses on the configuration and the tagged subordinates
    rand int unsigned cfg_weight;
    rand int unsigned tag_weight;

    // Configuration accesses: which offsets they go to, and how many in a hundred write
    rand tagctrl_cfg_scope_e cfg_scope;
    rand int unsigned        cfg_write_pct;

    // Region register writes take any value, not only the values above
    rand bit region_any;

    // Read back every configuration write at once
    rand bit cfg_write_readback;

    // How many tagged accesses in a hundred write
    rand int unsigned tag_write_pct;

    // Read back every tagged write after the random accesses, in the order written
    rand bit tag_readback;

    `uvm_object_utils_begin(tagctrl_seq_cfg)
      `uvm_field_int(configure, UVM_DEFAULT)
      `uvm_field_int(baseline_cfg, UVM_DEFAULT)
      `uvm_field_int(covered_base, UVM_DEFAULT)
      `uvm_field_int(covered_top, UVM_DEFAULT)
      `uvm_field_int(tag_table_base, UVM_DEFAULT)
      `uvm_field_enum(tagctrl_walk_e, walk, UVM_DEFAULT)
      `uvm_field_int(num_ops, UVM_DEFAULT | UVM_DEC)
      `uvm_field_int(cfg_weight, UVM_DEFAULT | UVM_DEC)
      `uvm_field_int(tag_weight, UVM_DEFAULT | UVM_DEC)
      `uvm_field_enum(tagctrl_cfg_scope_e, cfg_scope, UVM_DEFAULT)
      `uvm_field_int(cfg_write_pct, UVM_DEFAULT | UVM_DEC)
      `uvm_field_int(region_any, UVM_DEFAULT)
      `uvm_field_int(cfg_write_readback, UVM_DEFAULT)
      `uvm_field_int(tag_write_pct, UVM_DEFAULT | UVM_DEC)
      `uvm_field_int(tag_readback, UVM_DEFAULT)
    `uvm_object_utils_end

    function new(string name = "tagctrl_seq_cfg");
      super.new(name);
    endfunction

    // The controller is started only with the baseline layout
    constraint configure_c {
      configure dist {1 := 4, 0 := 1};
      configure -> baseline_cfg;
    }

    // Mostly aligned. A covered top below the base is left out, since it is no practical size.
    constraint region_c {
      covered_top >= covered_base;
      covered_top - covered_base <= MaxCoveredBytes;
      covered_base[12:0] dist {0 :/ 9, [1:13'h1fff] :/ 1};
      covered_top[12:0] dist {0 :/ 9, [1:13'h1fff] :/ 1};
      tag_table_base[5:0] dist {0 :/ 9, [1:6'h3f] :/ 1};
    }

    // A 4 MiB covered region, beyond the reach of the leaf cache, with uncovered space below and
    // above it, a tag table outside it, and every boundary 8 KiB aligned
    constraint baseline_cfg_c {
      baseline_cfg -> {
        covered_base % 8192 == 0;
        covered_top == covered_base + 64'h40_0000;
        covered_base >= 8192;
        covered_top <= 64'hffff_ffff_ffff_e000;
        tag_table_base % 8192 == 0;
        tag_table_base <= 64'hffff_ffff_fff0_0000;
        tag_table_base + 64'h10_0000 <= covered_base || tag_table_base >= covered_top;
      }
    }

    constraint walk_c {
      walk dist {WalkNone := 8, WalkRead := 1, WalkWriteRead := 1};
    }

    constraint num_ops_c {
      num_ops inside {[1:MaxOps]};
    }

    // Tagged accesses go to the covered region, so they need the controller started
    constraint port_weight_c {
      cfg_weight inside {[0:4]};
      tag_weight inside {[0:4]};
      cfg_weight + tag_weight > 0;
      cfg_weight dist {0 := 1, [1:4] :/ 8};
      tag_weight dist {0 := 1, [1:4] :/ 8};
      !configure -> tag_weight == 0;
    }

    constraint cfg_op_c {
      cfg_scope dist {CfgScopeAll := 8, CfgScopeRegion := 1, CfgScopeStatus := 1};
      cfg_write_pct inside {[0:100]};
      cfg_write_pct dist {0 := 1, [1:99] :/ 8, 100 := 1};
      region_any dist {0 := 4, 1 := 1};
      cfg_write_readback dist {0 := 3, 1 := 1};
    }

    constraint tag_op_c {
      tag_write_pct inside {[0:100]};
      tag_write_pct dist {0 := 1, [1:99] :/ 8, 100 := 1};
      tag_readback dist {0 := 3, 1 := 1};
    }
  endclass
