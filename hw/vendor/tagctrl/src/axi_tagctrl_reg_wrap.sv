// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Authors:
// - Nicole Narr <narrn@ethz.ch>
// - Christopher Reinwardt <creinwar@ethz.ch>
// Date:   17.11.2022

`include "axi_llc/typedef.svh"
`include "axi_llc/assign.svh"

/// Wraps the top_level of the axi_llc with structs as AXI connections and a regbus-accessible
/// register file.
/// The standard configuration is a cache size of 512KByte with a set-associativity
/// of 8, and line length of 8 blocks, one block equals the AXI data width of the
/// master port. Each set, also called way, can be configured to be directly
/// accessible as scratch pad memory. This can be done by setting the corresponding
/// register.
///
/// AXI ports: The FULL AXI ports, have different ID widths. The master ports ID is
///            one bit wider than the slave port. The reason is the `axi_mux` which
///            controls the AXI bypass.
///
/// # AXI4+ATOP Last Level Cache (LLC)
///
/// This is the top-level module of `axi_llc`.
///
/// ## Overview
///
/// Features:
/// * Write-back last level cache.
/// * Multiple outstanding transactions, priority for cache hits.
/// * Hot configurable scratch-pad memory.
///   * Individual cache sets can be configured to be direct addressable scratch pad while
///     cache is in operation.
///   * Contend of set is flushed back to memory.
/// * Bypass for non-cached memory accesses. (Bypass active when all sets are configured as SPM.)
/// * User configurable cache flush: See [`axi_llc_config`](module.axi_llc_config)
/// * Performance counters: See [`axi_llc_config`](module.axi_llc_config)
///
/// ![Block-diagram he Top Level of the LLC.](axi_llc_top.svg "Block-diagram of the Top Level of the LLC.")
///
///
/// It is required to provide the detailed AXI4+ATOP and configuration register structs as parameters.
/// The structs follow the naming scheme *port*\_*xx*\_chan_t. Where *port* stands for the
/// respective port and have the values *slv* and *mst*. In addition the respective request
/// and response structs have to be given. The address rule struct from the
/// `common_cells/addr_decode` has to be specified for the AXI4+ATOP ports as they are
/// used internally to provide address mapping for the AXI transfers onto the different SPM and
/// cache regions.
///
/// The overall size in bytes of the LLC in byte can be calculated with:
///
/// ![Equation axi_llc size](axi_llc_size_equ.gif "Equation axi_llc size")
///
/// ## Operation principle
///
/// The AXI4 protocol issues its transfers in a bursted fashion. The architecture of the LLC uses
/// most of the control information provided by the protocol to implement the cache control in a
/// decentralized way. For this it uses a data-flow driven control scheme.
///
/// The premise is that an AXI transfer gets translated into a number of descriptors which then flow
/// through a pipeline. Each descriptor maps the specific operation onto a cache line and basically
/// translates long bursts onto shorter ones which exactly map onto a single cache line.
/// For example when an AXI4+ATOP burst wants to write on three cache-lines, the control beat gets
/// translated into three descriptors which then flow through the pipeline.
///
/// Example of a write transfer when it accesses the cache:
/// * AW beat is valid on the slave port of the LLC.
/// * AW address gets decoded in the configuration module.
/// * AW enters the split unit and first descriptor enters the spill register.
/// * Request gets issued to the tag-storage (comprised of one SRAM block per set of the cache).
/// * Hit or miss and exact cacheline location (set) is determined. The dirty flag is set.
///   Cache line is locked for other following descriptors. Lock is taken away when descriptor
///   is finished with operation on this cache line.
/// * On hit:
///   * Descriptor goes directly to the write unit, takes hit bypass.
///   * Allows hits to overtake misses, if the AXI ID is different.
/// * On miss:
///   * Descriptor goes to the eviction/refill pipeline.
///   * If the cache-line is dirty it gets evicted by issuing a write request on the AXI4+ATOP
///     master port.
///   * Cache line is refilled from main memory.
///   * Descriptor is transferred into the write unit.
///  * Write unit sends the W beats from the CPU towards the data storage.
///  * Write unit issues a B beat back to the CPU, when the last W beat of the AXI4+ATOP
///    transfer is sent to the LLC data storage.
///
/// Reads are analogous to writes and use the same pipeline.
///
/// The hit bypass allows AXI4+ATOP transaction hitting onto the cache to overtake ones that are in
/// the miss pipeline.
/// Example: This has the advantage that a short write transaction from a CPU can overtake a long
///          read transactions (DMA). The feature requires that the AXI4+ATOP IDs of the transfers
///          are different.
///
/// Following table shows the internal struct which is used to define a
/// [cache descriptor](type llc_desc_t).
/// Part of the descriptor uses directly types defined in `axi_pkg`.
/// The other fields get defined when instantiating the design.
///
/// | Name        | Type               | Function |
/// |:----------- |:------------------ |:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
/// | `a_x_id`    | `axi_slv_id_t`     | The AXI4+ATOP ID of the burst entering through the slave port of the design. It has the same width as the slave port AXI ID.                                                                                                                                                                                |
/// | `a_x_addr`  | `axi_addr_t`       | The address of the descriptor. Aligned to the corresponding cache block.                                                                                                                                                                                                                                    |
/// | `a_x_len`   | `axi_pkg::len_t`   | AXI4+ATOP burst length field. Corresponds to the number of beats which map onto the cache line accessed by this descriptor. Gets set in the splitting unit which does the mapping onto the cache line.                                                                                                      |
/// | `a_x_size`  | `axi_pkg::size_t`  | AXI4+ATOP size field. This is important for the write and read unit to find the exact block and byte offset. Used for calculating the block location in the data storage.                                                                                                                                   |
/// | `a_x_burst` | `axi_pkg::burst_t` | AXI4+ATOP burst type. This is important for the splitter unit as well as the read and write unit. It determines the descriptor field `a_x_addr`.                                                                                                                                                            |
/// | `a_x_lock`  | `logic`            | AXI4+ATOP lock signal. Passed further in the miss pipeline when the line gets evicted or refilled.                                                                                                                                                                                                          |
/// | `a_x_cache` | `axi_pkg::cache_t` | AXI4+ATOP cache signal. The cache only supports write back mode.                                                                                                                                                                                                                                            |
/// | `a_x_prot`  | `axi_pkg::prot_t`  | AXI4+ATOP protection signal. Passed further in the miss pipeline.                                                                                                                                                                                                                                           |
/// | `x_resp`    | `axi_pkg::resp_t`  | AXI4+ATOP response signal. This tells if we try to make un-allowed accesses onto address regions which are not mapped to either SPM nor cache. When this signal gets set somewhere in the pipeline, all following modules will pass the descriptor along and absorb the corresponding beats from the ports. |
/// | `x_last`    | `logic`            | AXI4+ATOP last flag. Defines if the read or write unit send back the response.                                                                                                                                                                                                                              |
/// | `spm`       | `logic`            | This field signals that the descriptor is of type SPM. It will not make a lookup in the hit/miss detection and utilize the hit bypass if applicable.                                                                                                                                                        |
/// | `rw`        | `logic`            | This field determines if the descriptor makes a write access `1'b1` or read access `1'b0`.                                                                                                                                                                                                                  |
/// | `way_ind`   | `logic`            | The way indicator. Is a vector of width equal of the set-associativity. Decodes the index of the cache set where the descriptor should make an access.                                                                                                                                                      |
/// | `evict`     | `logic`            | The eviction flag. The descriptor missed and the line at the position was determined dirty by the detection. The evict unit will write back the dirty cache-line to the main memory.                                                                                                                        |
/// | `evict_tag` | `logic`            | The eviction tag. As the field `a_x_addr` has the new tag in it, it is used to send back the right address to the main memory during eviction.                                                                                                                                                              |
/// | `refill`    | `logic`            | The refill flag. The descriptor will trigger a read transaction to the main memory, refilling the cache-line.                                                                                                                                                                                               |
/// | `flush`     | `logic`            | The flush flag. This only gets set when a way should be flushed. It gets only set by descriptors coming from the configuration module.
module axi_tagctrl_reg_wrap #(
    /// DRAM memory Base
    parameter int unsigned DRAMMemBase      = 0,
    /// DRAM memory Length
    parameter int unsigned DRAMMemLength    = 0,
    /// Capability size in memory
    parameter int unsigned CapSize          = 128,
    /// Tag Cache base address in memory. Location of the Tag Cache
    /// structure
    parameter int unsigned TagCacheMemBase  = 0,
    /// The set-associativity of the LLC.
    ///
    /// This parameter determines how many ways/sets will be instantiated.
    ///
    /// Restrictions:
    /// * Minimum value: `32'd1`
    /// * Maximum value: `32'd63`
    /// The maximum value depends on the internal register width
    parameter int unsigned SetAssociativity = 32'd0,
    /// Number of cache lines per way.
    ///
    /// Restrictions:
    /// * Minimum value: `32'd2`
    /// * Has to be a power of two.
    ///
    /// Note on restrictions:
    /// The reason is that in the address, at least one bit has to be mapped onto a cache-line index.
    /// This is a limitation of the *system verilog* language, which requires at least one bit wide
    /// fields inside of a struct. Further this value has to be a power of 2. This has to do with the
    /// requirement that the address mapping from the address onto the cache-line index has to be
    /// continuous.
    parameter int unsigned NumLines         = 32'd0,
    /// Number of blocks (words) in a cache line.
    ///
    /// The width of a block is the same as the data width of the AXI4+ATOP ports. Defined with
    /// parameter `AxiCfg.DataWidthFull` in bits.
    ///
    /// Restrictions:
    /// * Minimum value: 32'd2
    /// * Has to be a power of two.
    ///
    /// Note on restrictions:
    /// The same restriction as of parameter `NumLines` applies.
    parameter int unsigned NumBlocks        = 32'd0,
    /// AXI4+ATOP ID field width of the slave port.
    /// The ID field width of the master port is this parameter + 1.
    parameter int unsigned AxiIdWidth       = 32'd0,
    /// AXI4+ATOP address field width of both the slave and master port.
    parameter int unsigned AxiAddrWidth     = 32'd0,
    /// AXI4+ATOP data field width of both the slave and the master port.
    parameter int unsigned AxiDataWidth     = 32'd0,
    /// AXI4+ATOP user field width of both the slave and the master port.
    parameter int unsigned AxiUserWidth     = 32'd0,
    /// AXI4+ATOP request type on the slave port.
    /// Expected format can be defined using `AXI_TYPEDEF_REQ_T.
    parameter type         slv_req_t        = logic,
    /// AXI4+ATOP response type on the slave port.
    /// Expected format can be defined using `AXI_TYPEDEF_RESP_T.
    parameter type         slv_resp_t       = logic,
    /// AXI4+ATOP request type on the master port.
    /// Expected format can be defined using `AXI_TYPEDEF_REQ_T.
    parameter type         mst_req_t        = logic,
    /// AXI4+ATOP response type on the master port.
    /// Expected format can be defined using `AXI_TYPEDEF_RESP_T.
    parameter type         mst_resp_t       = logic,
    /// Configuration RegBus interface request type
    parameter type         reg_req_t        = logic,
    /// Configuration RegBus interface response type
    parameter type         reg_resp_t       = logic,
    /// Full AXI4+ATOP Port address decoding rule
    parameter type         rule_full_t      = axi_pkg::xbar_rule_64_t,
    /// Whether to print SRAM configs
    parameter bit          PrintSramCfg     = 0,
    /// Dependent parameter, do **not** overwrite!
    /// Address type of the AXI4+ATOP ports.
    /// The address fields of the rule type have to be the same.
    parameter type         axi_addr_t       = logic                   [    AxiAddrWidth-1:0],
    /// Dependent parameter, do **not** overwrite!
    /// Data type of set associativity wide registers
    parameter type         way_ind_t        = logic                   [SetAssociativity-1:0]
) (
    /// Rising-edge clock of all ports.
    input logic clk_i,
    /// Asynchronous reset, active low
    input logic rst_ni,
    /// Test mode activate, active high.
    input logic test_i,
    /// AXI4+ATOP slave port request, CPU side
    input slv_req_t slv_req_i,
    /// AXI4+ATOP slave port response, CPU side
    output slv_resp_t slv_resp_o,
    /// AXI4+ATOP master port request, memory side
    output mst_req_t mst_req_o,
    /// AXI4+ATOP master port response, memory side
    input mst_resp_t mst_resp_i,
    /// Configuration RegBus interface - request
    input reg_req_t conf_req_i,
    /// Configuration RegBus interface - response
    output reg_resp_t conf_resp_o,
    /// Start of address region mapped to cache
    input axi_addr_t cached_start_addr_i,
    /// End of address region mapped to cache
    input axi_addr_t cached_end_addr_i
);

  // Define 64-bit register types for the AXI_LLC toplevel
  `AXI_LLC_TYPEDEF_ALL(axi_llc, logic [63:0], way_ind_t)

  // Generated register file interface variables
  axi_llc_reg_pkg::axi_llc_reg2hw_t config_reg2hw;
  axi_llc_reg_pkg::axi_llc_hw2reg_t config_hw2reg;

  // Variables for the AXI_LLC registers
  axi_llc_cfg_regs_d_t config_regs_d;
  axi_llc_cfg_regs_q_t config_regs_q;

  // Connecting the generated register file structs and the AXI_LLC register structs
  `AXI_LLC_ASSIGN_REGS_Q_FROM_REGBUS(config_regs_q, config_reg2hw)
  `AXI_LLC_ASSIGN_REGBUS_FROM_REGS_D(config_hw2reg, config_regs_d)

  // Generated 32-bit RegBus register file
  axi_llc_reg_top #(
      .reg_req_t(reg_req_t),
      .reg_rsp_t(reg_resp_t)
  ) i_llc_config_regfile (
      .clk_i,
      .rst_ni,
      .reg_req_i(conf_req_i),
      .reg_rsp_o(conf_resp_o),

      // To HW
      .reg2hw(config_reg2hw),  // Write
      .hw2reg(config_hw2reg),  // Read

      // Config
      .devmode_i(1'b1)  // If 1, explicit error return for unmapped register access
  );

  // Registerfile agnostic axi_llc toplevel - configured for 64-bit internal registers
  axi_tagctrl_top #(
      .CapSize         (CapSize),
      .TagCacheMemBase (TagCacheMemBase),
      .DRAMMemBase     (DRAMMemBase),
      .SetAssociativity(SetAssociativity),
      .NumLines        (NumLines),
      .NumBlocks       (NumBlocks),
      .AxiIdWidth      (AxiIdWidth),
      .AxiAddrWidth    (AxiAddrWidth),
      .AxiDataWidth    (AxiDataWidth),
      .AxiUserWidth    (AxiUserWidth),
      .RegWidth        (32'd64),
      .conf_regs_d_t   (axi_llc_cfg_regs_d_t),
      .conf_regs_q_t   (axi_llc_cfg_regs_q_t),
      .slv_req_t       (slv_req_t),
      .slv_resp_t      (slv_resp_t),
      .mst_req_t       (mst_req_t),
      .mst_resp_t      (mst_resp_t),
      .rule_full_t     (rule_full_t),
      .PrintSramCfg    (PrintSramCfg)
  ) i_axi_tagctrl_top_raw (
      .clk_i,
      .rst_ni,
      .test_i,
      .slv_req_i,
      .slv_resp_o,
      .mst_req_o,
      .mst_resp_i,

      .conf_regs_i(config_regs_q),
      .conf_regs_o(config_regs_d),

      .cached_start_addr_i,
      .cached_end_addr_i
  );

endmodule
