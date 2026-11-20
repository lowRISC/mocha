`ifndef AXI_TAGCTRL_TYPEDEF_SVH_
`define AXI_TAGCTRL_TYPEDEF_SVH_

`define AXI_TAGCTRL_TYPEDEF_READ_RESP_T(name_t, id_t, data_t) \
  typedef struct packed {                                     \
    id_t            id;                                       \
    data_t          data;                                     \
    axi_pkg::resp_t resp;                                     \
    logic           last;                                     \
    logic           aborted;                                  \
    logic           hit;                                      \
  } name_t;

`define AXI_TAGCTRL_TYPEDEF_DATA_REQ_T(name_t, data_t) \
  typedef struct packed {                              \
    data_t data;                                       \
    data_t bit_en;                                     \
  } name_t;

`endif
