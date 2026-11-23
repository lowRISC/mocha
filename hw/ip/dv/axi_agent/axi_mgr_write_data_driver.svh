// Copyright lowRISC and contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

// A driver for axi_write_data_if, used when the testbench is acting as an AXI Manager that is
// sending write data transfers.

class axi_mgr_write_data_driver extends uvm_driver#(axi_write_data_item, axi_status_item);
  `uvm_component_utils(axi_mgr_write_data_driver)

  local virtual axi_write_data_if m_vif;
  local virtual clk_rst_if m_clk_rst_vif;

  // True once a clock edge has sampled rst_ni high since reset was released. VALID rises only after
  // such an edge (H.c A3.1.2). Maintained by monitor_reset().
  local bit m_release_sampled;

  // How to drive this channel's payload while it is idle. Set this with set_drive_x_when_idle
  // before run_phase; see axi_if::drive_x_when_idle for what the two settings mean.
  local bit m_drive_x_when_idle = 1'b1;

  // Set AXI4-Lite mode with set_lite()
  local bit m_is_lite;

  extern function new(string name, uvm_component parent);
  extern virtual task run_phase(uvm_phase phase);

  // Set m_vif. This must be called before run_phase.
  extern function void set_vif(virtual axi_write_data_if vif);

  // Set the shared clock/reset interface. This must be called before run_phase.
  extern function void set_clk_rst_vif(virtual clk_rst_if vif);

  // Set how the idle signals are driven. This must be called before run_phase.
  extern function void set_drive_x_when_idle(bit drive_x);

  // Set AXI4-Lite mode before run_phase
  extern function void set_lite(bit is_lite);

  // Run forever, consuming and driving items from seq_item_port
  extern local task get_and_drive();

  // Run forever, tracking rst_ni and maintaining the release_sampled class variable. Calls
  // clear_data when reset becomes asserted.
  extern local task monitor_reset();

  // A task that is called at the start of a reset and also at the end of driving an item.
  extern local task clear_data();

  // A task that drives the axi_write_data_item in the req class variable
  //
  // This returns when the item is driven, setting item_sent=1, or returns early if a reset is
  // asserted, in which case it sets item_sent=0.
  extern local task drive_req(output bit item_sent);

  // Set data values in the interface based on the req item. This task runs in zero time (but uses
  // clocking block drives, so cannot be a function).
  //
  // This task also checks sizes against the DATA_WIDTH and USER_DATA_WIDTH properties that are
  // configured in the interface.
  extern local task set_data_from_req();
endclass

function axi_mgr_write_data_driver::new(string name, uvm_component parent);
  super.new(name, parent);
endfunction

function void axi_mgr_write_data_driver::set_vif(virtual axi_write_data_if vif);
  if (m_vif != null) begin
    `uvm_fatal(get_full_name(), "Cannot call set_vif: there is already an interface.")
    return;
  end

  if (vif.if_mode != Manager) begin
    `uvm_fatal(get_full_name(),
               $sformatf("Cannot drive this interface: it has mode %0s, not Manager.",
                         vif.if_mode.name()))
    return;
  end

  m_vif = vif;
endfunction

function void axi_mgr_write_data_driver::set_clk_rst_vif(virtual clk_rst_if vif);
  m_clk_rst_vif = vif;
endfunction

function void axi_mgr_write_data_driver::set_drive_x_when_idle(bit drive_x);
  m_drive_x_when_idle = drive_x;
endfunction

function void axi_mgr_write_data_driver::set_lite(bit is_lite);
  m_is_lite = is_lite;
endfunction: set_lite

task axi_mgr_write_data_driver::run_phase(uvm_phase phase);
  if (m_vif == null || m_clk_rst_vif == null) begin
    `uvm_fatal(get_full_name(), "Cannot drive interface: either m_vif or m_clk_rst_vif is null.")
    return;
  end

  // Start by clearing the data (and, importantly, setting m_vif.mgr_cb.wvalid = 0). From now,
  // wvalid will be zero unless $isunknown on all the data fields is false.
  clear_data();

  fork
    get_and_drive();
    monitor_reset();
  join
endtask

task axi_mgr_write_data_driver::get_and_drive();
  axi_status_item status_item;
  forever begin
    seq_item_port.get_next_item(req);
    status_item = axi_status_item::type_id::create("status_item");
    status_item.set_id_info(req);
    drive_req(status_item.m_sending_complete);
    seq_item_port.item_done(status_item);
  end
endtask

task axi_mgr_write_data_driver::monitor_reset();
  realtime release_time;

  forever begin
    wait (m_clk_rst_vif.rst_n);

    // An edge in the time step of the release may have sampled rst_ni low, so wait for a later one
    release_time = $realtime;
    fork : isolation_fork begin
      fork
        wait (!m_clk_rst_vif.rst_n);
        begin
          do begin
            @(m_vif.mon_cb);
          end while ($realtime == release_time);
          m_release_sampled = 1'b1;
        end
      join_any
      disable fork;
    end join

    wait (!m_clk_rst_vif.rst_n);
    m_release_sampled = 1'b0;
    clear_data();
  end
endtask

task axi_mgr_write_data_driver::clear_data();
  bit   [AxiMaxDataWidth-1:0]     idle_data;
  bit   [AxiMaxStrbWidth-1:0]     idle_strb;
  bit                             idle_last;
  bit   [AxiMaxDataUserWidth-1:0] idle_user;

  m_vif.mgr_cb.wvalid <= 1'b0;

  // AXI requires nothing of the payload while WVALID is low, so drive it meaningless: X by
  // default, or randomised for a sink that cannot tolerate X (see axi_if::drive_x_when_idle).
  if (m_drive_x_when_idle) begin
    m_vif.mgr_cb.wdata <= 'x;
    m_vif.mgr_cb.wstrb <= 'x;
    m_vif.mgr_cb.wlast <= 'x;
    m_vif.mgr_cb.wuser <= 'x;
  end else begin
    if (!std::randomize(idle_data, idle_strb, idle_last, idle_user)) begin
      `uvm_fatal(get_full_name(), "Failed to randomize the idle W payload.")
    end
    m_vif.mgr_cb.wdata <= idle_data;
    m_vif.mgr_cb.wstrb <= idle_strb;
    m_vif.mgr_cb.wlast <= idle_last;
    m_vif.mgr_cb.wuser <= idle_user;
  end
endtask

task axi_mgr_write_data_driver::drive_req(output bit item_sent);
  // Return the item unsent while reset is asserted. This reads the pin, which monitor_reset() waits
  // on too, so an item that arrives in the time step of the release is kept whichever runs first.
  if (m_clk_rst_vif.rst_n === 1'b0) return;

  fork : isolation_fork begin
    fork
      wait (m_clk_rst_vif.rst_n === 1'b0);
      begin
        // An item that arrives as reset is released waits for an edge that samples it (H.c A3.1.2).
        // The pin check keeps VALID low when reset asserts in the time step of that edge.
        wait (m_release_sampled && m_clk_rst_vif.rst_n === 1'b1);
        set_data_from_req();
        m_vif.mgr_cb.wvalid <= 1;

        // Count a transfer only when sampled WVALID and WREADY are both high (H.c A3.2.1). For an
        // item received between edges, WVALID reaches the bus at the next edge; WREADY alone is
        // insufficient.
        do begin
          @(m_vif.mon_cb);
        end while (!(m_vif.mon_cb.wvalid === 1'b1 && m_vif.mon_cb.wready === 1'b1));

        clear_data();

        // Because we finished sending the item, set item_sent to cause get_and_drive to set
        // m_sending_complete in its response.
        item_sent = 1'b1;
      end
    join_any
    disable fork;
  end join

  // A launch that reset cut short may have driven VALID after monitor_reset() cleared it
  if (!item_sent) begin
    clear_data();
  end
endtask

task axi_mgr_write_data_driver::set_data_from_req();
  // Check that configurable-length item fields actually fit in the interface signals. Note: we can
  // safely drive all the bits in the clocking block here anyway: they will be truncated in the
  // interface when being reflected in the "*_internal" signal.
  if (|(req.m_data >> m_vif.data_width)) begin
    `uvm_error(get_full_name(),
               $sformatf("Cannot represent req.m_data = 0x%0h. The interface DATA_WIDTH is %0d.",
                         req.m_data, m_vif.data_width))
  end
  if (|(req.m_strb >> ((m_vif.data_width + 7) / 8))) begin
    `uvm_error(get_full_name(),
               $sformatf({"Cannot represent req.m_strb = 0x%0h. ",
                          "The interface DATA_WIDTH is %0d, giving a strobe width of %0d."},
                         req.m_strb, m_vif.data_width, ((m_vif.data_width + 7) / 8)))
  end
  if (|(req.m_user >> m_vif.user_data_width)) begin
    `uvm_error(get_full_name(),
               $sformatf({"Cannot represent req.m_user = 0x%0h. ",
                          "The interface user_data_width is %0d."},
                         req.m_user, m_vif.user_data_width))
  end

  // AXI4-Lite transfers have one beat, so WLAST is always 1 (AMBA AXI H.c B1.1.1)
  if (m_is_lite && !req.m_last) begin
    `uvm_error(get_full_name(), "AXI4-Lite needs WLAST 1 on every beat.")
  end

  m_vif.mgr_cb.wdata  <= req.m_data;
  m_vif.mgr_cb.wstrb  <= req.m_strb;
  m_vif.mgr_cb.wlast  <= req.m_last;
  m_vif.mgr_cb.wuser  <= req.m_user;
endtask
