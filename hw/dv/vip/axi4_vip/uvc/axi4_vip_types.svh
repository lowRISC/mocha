`ifndef AXI4_VIP_TYPES_SVH
`define AXI4_VIP_TYPES_SVH

typedef enum {AXI_READ, AXI_WRITE} t_axi_dir;

typedef enum {
  AXI_AW_CH,
  AXI_W_CH,
  AXI_B_CH,
  AXI_AR_CH,
  AXI_R_CH,
  AXI_FULL_TR
} t_axi_obs;

`endif // AXI4_VIP_TYPES_SVH