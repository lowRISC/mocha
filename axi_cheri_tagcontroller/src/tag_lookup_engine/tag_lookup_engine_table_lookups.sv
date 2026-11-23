module tag_lookup_engine_table_lookups #(
  parameter type tag_req_t = logic,
  parameter type tag_data_req_t = logic,
  parameter type tag_write_resp_t = logic,
  parameter type tag_read_resp_t = logic,
  parameter type axi_addr_t = logic,
  parameter type axi_slv_id_t = logic,
  parameter int unsigned GROUPING_FACTOR = 256,
  parameter int unsigned BITS_PER_ROOT_FLIT = 4,
  parameter int unsigned BITS_PER_LEAF_FLIT = 4
) (
  input logic clk_i,
  input logic rst_ni,
  input axi_addr_t root_table_size_i,
  // commands / reporting signals
  input logic perform_zeroing_i,
  output logic done_zeroing_o,
  input logic perform_flushing_i, // TODO implement
  output logic done_flushing_o, // TODO implement
  // incoming requests interface
  input  logic            read_req_valid_i,
  output logic            read_req_ready_o,
  input  tag_req_t        read_req_i,
  output logic            read_resp_valid_o,
  input  logic            read_resp_ready_i,
  output tag_read_resp_t  read_resp_o,
  input  logic            write_req_valid_i,
  output logic            write_req_ready_o,
  input  tag_req_t        write_req_i,
  input  logic            write_data_req_valid_i,
  output logic            write_data_req_ready_o,
  input  tag_data_req_t   write_data_req_i,
  output logic            write_resp_valid_o,
  input  logic            write_resp_ready_i,
  output tag_write_resp_t write_resp_o,
  // root level interface
  output logic            root_read_req_valid_o[2],
  input  logic            root_read_req_ready_i[2],
  output tag_req_t        root_read_req_o[2],
  input  logic            root_read_resp_valid_i[2],
  output logic            root_read_resp_ready_o[2],
  input  tag_read_resp_t  root_read_resp_i[2],
  output logic            root_write_req_valid_o[2],
  input  logic            root_write_req_ready_i[2],
  output tag_req_t        root_write_req_o[2],
  output logic            root_write_req_flush_o[2],
  output logic            root_write_data_req_valid_o[2],
  input  logic            root_write_data_req_ready_i[2],
  output tag_data_req_t   root_write_data_req_o[2],
  input  logic            root_write_resp_valid_i[2],
  output logic            root_write_resp_ready_o[2],
  input  tag_write_resp_t root_write_resp_i[2],
  // leaf level interface
  output logic            leaf_read_req_valid_o[2],
  input  logic            leaf_read_req_ready_i[2],
  output tag_req_t        leaf_read_req_o[2],
  output logic            leaf_read_req_speculative_o[2],
  input  logic            leaf_read_resp_valid_i[2],
  output logic            leaf_read_resp_ready_o[2],
  input  tag_read_resp_t  leaf_read_resp_i[2],
  output logic            leaf_write_req_valid_o,
  input  logic            leaf_write_req_ready_i,
  output tag_req_t        leaf_write_req_o,
  output logic            leaf_write_req_flush_o,
  output logic            leaf_write_data_req_valid_o,
  input  logic            leaf_write_data_req_ready_i,
  output tag_data_req_t   leaf_write_data_req_o,
  input  logic            leaf_write_resp_valid_i,
  output logic            leaf_write_resp_ready_o,
  input  tag_write_resp_t leaf_write_resp_i,
  // performance events
  output axi_tagctrl_pkg::tag_lookup_engine_table_lookups_events_t events_o
);

  // helpers //
  function automatic axi_addr_t cap_addr_to_root_idx(axi_addr_t cap_addr);
    return cap_addr >> $clog2(GROUPING_FACTOR);
  endfunction

  assign root_write_req_flush_o[1] = 1'b0; // all flushes use ifc[0]

  // Tie off unused leaf read port 1
  assign leaf_read_req_valid_o[1] = 1'b0;
  assign leaf_read_resp_ready_o[1] = 1'b0;
  assign leaf_read_req_o[1] = '0;
  assign leaf_read_req_speculative_o[1] = 1'b0;

  // output mux for write leaf and root interface sharing between
  // write lookups module and flushing module
  logic            root_write_req_valid_flushing, root_write_req_valid_lookups;
  tag_req_t        root_write_req_lookups;
  logic            root_write_data_req_valid_flushing, root_write_data_req_valid_lookups;
  tag_data_req_t   root_write_data_req_lookups;
  logic            root_write_resp_ready_flushing, root_write_resp_ready_lookups;
  logic            leaf_write_req_valid_flushing, leaf_write_req_valid_lookups;
  tag_req_t        leaf_write_req_lookups;
  logic            leaf_write_data_req_valid_flushing, leaf_write_data_req_valid_lookups;
  tag_data_req_t   leaf_write_data_req_lookups;
  logic            leaf_write_resp_ready_flushing, leaf_write_resp_ready_lookups;

  assign root_write_req_valid_o[0] = done_flushing_o ? root_write_req_valid_lookups : root_write_req_valid_flushing;
  assign root_write_req_o[0] = done_flushing_o ? root_write_req_lookups : '0;
  assign root_write_req_flush_o[0] = done_flushing_o ? 1'b0 : 1'b1;
  assign root_write_data_req_valid_o[0] = done_flushing_o ? root_write_data_req_valid_lookups : root_write_data_req_valid_flushing;
  assign root_write_data_req_o[0] = done_flushing_o ? root_write_data_req_lookups : '0;
  assign root_write_resp_ready_o[0] = done_flushing_o ? root_write_resp_ready_lookups : root_write_resp_ready_flushing;

  assign leaf_write_req_valid_o = done_flushing_o ? leaf_write_req_valid_lookups : leaf_write_req_valid_flushing;
  assign leaf_write_req_o = done_flushing_o ? leaf_write_req_lookups : '0;
  assign leaf_write_req_flush_o = done_flushing_o ? 1'b0 : 1'b1;
  assign leaf_write_data_req_valid_o = done_flushing_o ? leaf_write_data_req_valid_lookups : leaf_write_data_req_valid_flushing;
  assign leaf_write_data_req_o = done_flushing_o ? leaf_write_data_req_lookups : '0;
  assign leaf_write_resp_ready_o = done_flushing_o ? leaf_write_resp_ready_lookups : leaf_write_resp_ready_flushing;

  // flushing fsm
  tag_lookup_engine_flushing i_tag_lookup_engine_flushing (
    .clk_i,
    .rst_ni,
    .perform_flushing_i,
    .done_flushing_o,
    // outgoing root write interface
    .root_req_valid_o(root_write_req_valid_flushing),
    .root_req_ready_i(root_write_req_ready_i[0]),
    .root_data_valid_o(root_write_data_req_valid_flushing),
    .root_data_ready_i(root_write_data_req_ready_i[0]),
    .root_resp_valid_i(root_write_resp_valid_i[0] && !done_flushing_o),
    .root_resp_ready_o(root_write_resp_ready_flushing),
    // outgoing leaf write interface
    .leaf_req_valid_o(leaf_write_req_valid_flushing),
    .leaf_req_ready_i(leaf_write_req_ready_i),
    .leaf_data_valid_o(leaf_write_data_req_valid_flushing),
    .leaf_data_ready_i(leaf_write_data_req_ready_i),
    .leaf_resp_valid_i(leaf_write_resp_valid_i && !done_flushing_o),
    .leaf_resp_ready_o(leaf_write_resp_ready_flushing)
  );

  // root table management fsm
  tag_lookup_engine_root_init #(
    .tag_req_t(tag_req_t),
    .tag_data_req_t(tag_data_req_t),
    .tag_write_resp_t(tag_write_resp_t),
    .axi_addr_t(axi_addr_t),
    .BITS_PER_ROOT_FLIT(BITS_PER_ROOT_FLIT)
  ) i_tag_lookup_engine_root_init (
    .clk_i,
    .rst_ni,
    .root_table_size_i,
    .start_i(perform_zeroing_i),
    .ready_o(done_zeroing_o),
    .root_write_req_valid_o(root_write_req_valid_o[1]),
    .root_write_req_ready_i(root_write_req_ready_i[1]),
    .root_write_req_o(root_write_req_o[1]),
    .root_write_data_req_valid_o(root_write_data_req_valid_o[1]),
    .root_write_data_req_ready_i(root_write_data_req_ready_i[1]),
    .root_write_data_req_o(root_write_data_req_o[1]),
    .root_write_resp_valid_i(root_write_resp_valid_i[1]),
    .root_write_resp_ready_o(root_write_resp_ready_o[1]),
    .root_write_resp_i(root_write_resp_i[1])
  );

  // tag reads //
  tag_lookup_engine_table_lookups_read #(
    .tag_req_t(tag_req_t),
    .tag_read_resp_t(tag_read_resp_t),
    .axi_addr_t(axi_addr_t),
    .GROUPING_FACTOR(GROUPING_FACTOR)
  ) i_tag_lookup_engine_table_lookups_read (
    .clk_i,
    .rst_ni,
    // incoming interface
    .root_idx_i(cap_addr_to_root_idx(read_req_i.a_x_addr)),
    .req_valid_i(read_req_valid_i),
    .req_ready_o(read_req_ready_o),
    .req_i(read_req_i),
    .resp_valid_o(read_resp_valid_o),
    .resp_ready_i(read_resp_ready_i),
    .resp_o(read_resp_o),
    // outgoing root interface
    .root_req_valid_o(root_read_req_valid_o[0]),
    .root_req_ready_i(root_read_req_ready_i[0]),
    .root_req_o(root_read_req_o[0]),
    .root_resp_valid_i(root_read_resp_valid_i[0]),
    .root_resp_ready_o(root_read_resp_ready_o[0]),
    .root_resp_i(root_read_resp_i[0]),
    // outgoing leaf interface
    .leaf_req_valid_o(leaf_read_req_valid_o[0]),
    .leaf_req_ready_i(leaf_read_req_ready_i[0]),
    .leaf_req_o(leaf_read_req_o[0]),
    .leaf_req_speculative_o(leaf_read_req_speculative_o[0]),
    .leaf_resp_valid_i(leaf_read_resp_valid_i[0]),
    .leaf_resp_ready_o(leaf_read_resp_ready_o[0]),
    .leaf_resp_i(leaf_read_resp_i[0]),
    // performance events
    .events_o(events_o.read_events)
  );

  // tag writes //
  tag_lookup_engine_table_lookups_write #(
    .tag_req_t(tag_req_t),
    .tag_data_req_t(tag_data_req_t),
    .tag_write_resp_t(tag_write_resp_t),
    .tag_read_resp_t(tag_read_resp_t),
    .axi_addr_t(axi_addr_t),
    .axi_slv_id_t(axi_slv_id_t),
    .GROUPING_FACTOR(GROUPING_FACTOR),
    .BITS_PER_ROOT_FLIT(BITS_PER_ROOT_FLIT),
    .BITS_PER_LEAF_FLIT(BITS_PER_LEAF_FLIT)
  ) i_tag_lookup_engine_table_lookups_write (
    .clk_i(clk_i),
    .rst_ni(rst_ni),
    // incoming interface
    .root_idx_i(cap_addr_to_root_idx(write_req_i.a_x_addr)),
    .req_valid_i(write_req_valid_i),
    .req_ready_o(write_req_ready_o),
    .req_i(write_req_i),
    .data_valid_i(write_data_req_valid_i),
    .data_ready_o(write_data_req_ready_o),
    .data_i(write_data_req_i),
    .resp_valid_o(write_resp_valid_o),
    .resp_ready_i(write_resp_ready_i),
    .resp_o(write_resp_o),
    // outgoing root read interface
    .root_rd_req_valid_o(root_read_req_valid_o[1]),
    .root_rd_req_ready_i(root_read_req_ready_i[1]),
    .root_rd_req_o(root_read_req_o[1]),
    .root_rd_resp_valid_i(root_read_resp_valid_i[1]),
    .root_rd_resp_ready_o(root_read_resp_ready_o[1]),
    .root_rd_resp_i(root_read_resp_i[1]),
    // outgoing root write interface
    .root_req_valid_o(root_write_req_valid_lookups),
    .root_req_ready_i(root_write_req_ready_i[0]),
    .root_req_o(root_write_req_lookups),
    .root_data_valid_o(root_write_data_req_valid_lookups),
    .root_data_ready_i(root_write_data_req_ready_i[0]),
    .root_data_o(root_write_data_req_lookups),
    .root_resp_valid_i(root_write_resp_valid_i[0] && done_flushing_o),
    .root_resp_ready_o(root_write_resp_ready_lookups),
    .root_resp_i(root_write_resp_i[0]),
    // outgoing leaf write interface
    .leaf_req_valid_o(leaf_write_req_valid_lookups),
    .leaf_req_ready_i(leaf_write_req_ready_i),
    .leaf_req_o(leaf_write_req_lookups),
    .leaf_data_valid_o(leaf_write_data_req_valid_lookups),
    .leaf_data_ready_i(leaf_write_data_req_ready_i),
    .leaf_data_o(leaf_write_data_req_lookups),
    .leaf_resp_valid_i(leaf_write_resp_valid_i && done_flushing_o),
    .leaf_resp_ready_o(leaf_write_resp_ready_lookups),
    .leaf_resp_i(leaf_write_resp_i),
    // performance events
    .events_o(events_o.write_events)
  );

endmodule
