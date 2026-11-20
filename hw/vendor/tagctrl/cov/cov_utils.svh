`ifndef COV_UTILS_SVH
`define COV_UTILS_SVH

`define DEF_VALID_READY_COV(def_name, clk, rst_n, valid, ready) \
covergroup cg_``def_name``_valid_ready (string name) @(posedge clk iff rst_n); \
  option.per_instance = 1; \
  option.name = name; \
  cp_valid: coverpoint valid { \
    bins VALID     = {1'b1}; \
    bins NOT_VALID = {1'b0}; \
  } \
  cp_ready: coverpoint ready { \
    bins READY     = {1'b1}; \
    bins NOT_READY = {1'b0}; \
  } \
  cross cp_valid, cp_ready { \
    //bins VALID_READY         = binsof(cp_valid.VALID)     intersect {1'b1} && binsof(cp_ready.READY)     intersect {1'b1}; \
    //bins VALID_NOT_READY     = binsof(cp_valid.VALID)     intersect {1'b1} && binsof(cp_ready.NOT_READY) intersect {1'b0}; \
    //bins NOT_VALID_READY     = binsof(cp_valid.NOT_VALID) intersect {1'b0} && binsof(cp_ready.READY)     intersect {1'b1}; \
    //bins NOT_VALID_NOT_READY = binsof(cp_valid.NOT_VALID) intersect {1'b0} && binsof(cp_ready.NOT_READY) intersect {1'b0}; \
    bins VALID_READY = binsof(cp_valid.VALID) && binsof(cp_ready.READY); \
    bins VALID_NOT_READY = binsof(cp_valid.VALID) && binsof(cp_ready.NOT_READY); \
    bins NOT_VALID_READY = binsof(cp_valid.NOT_VALID) && binsof(cp_ready.READY); \
    bins NOT_VALID_NOT_READY = binsof(cp_valid.NOT_VALID) && binsof(cp_ready.NOT_READY); \
  } \
endgroup \
cg_``def_name``_valid_ready inst_cg_``def_name``_valid_ready = new($sformatf("%m"));

/*
    cross cp_valid, cp_ready {
      //bins VALID_READY = binsof(cp_valid.VALID) intersect binsof(cp_ready.READY);
      bins VALID_READY = binsof(cp_valid.VALID) && binsof(cp_ready.READY);
      bins VALID_NOT_READY = binsof(cp_valid.VALID) && binsof(cp_ready.NOT_READY);
      bins NOT_VALID_READY = binsof(cp_valid.NOT_VALID) && binsof(cp_ready.READY);
      bins NOT_VALID_NOT_READY = binsof(cp_valid.NOT_VALID) && binsof(cp_ready.NOT_READY);
    }
*/

`endif // COV_UTILS_SVH
