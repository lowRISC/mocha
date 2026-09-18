This file lists the module instatiations within CVA6-CHERI and their clock and reset connections.
Each module instantiation is listed as <instance_name> <module_name> <clk connection> <rst connection>.
Each instantiation is then followed by the signal names of the clock and reset given in the module interface.
The tree is terminated by the following possibilities:
* NOSUB: A 'leaf' module with no submodule definitions
* NOTFOUND: The module is not found within Mocha
* COMB_ONLY: The module has no clock or reset as it is purely combinational
* EXTERNAL: The module is defined outside of CVA6-CHERI
* REPEATMOD: The module has already been audited for a prior instantiation in the tree
* PARAM_OFF: The instantiation is parameterised out in the Mocha configuration

* i_cva6 cva6 .clk_i(clkmgr_clocks.clk_main_infra) .rst_ni(rstmgr_resets.rst_main_n[rstmgr_pkg::DomainMainSel])
  * clk_i rst_ni
    * i_frontend frontend .clk_i .rst_ni
      * clk_i rst_ni
        * i_instr_realign instr_realign .clk_i(clk_i) .rst_ni(rst_ni)
          * clk_i rst_ni
            * NOSUB
        * i_ras ras .clk_i .rst_ni
          * clk_i rst_ni
            * NOSUB
        * i_btb btb .clk_i .rst_ni
          * clk_i rst_ni
            * i_btb_ram SyncDpRam .Clk_CI(clk_i) .Rst_RBI(rst_ni)
              * NOTFOUND
        * i_bht bht .clk_i .rst_ni
          * clk_i rst_ni
            * i_bht_ram SyncThreePortRam .Clk_CI(clk_i) NORST
              * NOTFOUND
            * i_bht_ram AsyncThreePortRam .Clk_CI(clk_i) NORST
              * NOTFOUND
        * i_bht bht2lvl .clk_i .rst_ni
          * clk_i rst_ni
            * NOSUB
        * i_instr_scan instr_scan NOCLK NORST
          * COMB_ONLY
        * i_instr_queue instr_queue .clk_i(clk_i) .rst_ni(rst_ni)
          * clk_i rst_ni
            * i_lzc_branch_index lzc NOCLK NORST
              * COMB_ONLY
            * i_popcount popcount NOCLK NORST
              * COMB_ONLY
            * i_fifo_instr_data cva6_fifo_v3 .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
              * fifo_ram SyncDpRam_ind_r_w .Clk_CI(clk_i) NORST
                * NOTFOUND
              * fifo_ram AsyncDpRam .Clk_CI(clk_i) NORST
                * NOTFOUND
            * i_fifo_address cva6_fifo_v3 .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
              * REPEATMOD
    * id_stage_i id_stage .clk_i .rst_ni
      * clk_i rst_ni
        * compressed_decoder_i compressed_decoder NOCLK NORST
          * COMB_ONLY
        * macro_decoder_i macro_decoder .clk_i(clk_i) .rst_ni(rst_ni)
        * zcmt_decoder_i zcmt_decoder .clk_i(clk_i) .rst_ni(rst_ni)
        * cvxif_compressed_if_driver_i cvxif_compressed_if_driver .clk_i(clk_i) .rst_ni(rst_ni)
        * decoder_i decoder NOCLK NORST
    * issue_stage_i issue_stage .clk_i .rst_ni
      * clk_i rst_ni
        * i_scoreboard scoreboard .clk_i .rst_ni
        * i_issue_read_operands .clk_i .rst_ni
    * ex_stage_i ex_stage .clk_i(clk_i) .rst_ni(rst_ni)
      * clk_i rst_ni
        * alu_wrapper_i alu_wrapper .clk_i .rst_ni
        * branch_unit_i branch_unit .clk_i .rst_ni
        * csr_buffer_i csr_buffer .clk_i .rst_ni
        * i_mult mult .clk_i .rst_ni
        * fpu_i fpu_wrap .clk_i .rst_ni
        * lsu_i load_store_unit .clk_i .rst_ni
        * cvxif_fu_i cvxif_fi .clk_i .rst_ni
        * clu_i cheri_unit .clk_i .rst_ni
        * aes_i aes .clk_i .rst_ni
    * commit_stage_i commit_stage .clk_i .rst_ni
      * clk_i rst_ni
        * NOSUB
    * csr_regfile_i csr_regfile .clk_i .rst_ni
      * clk_i rst_ni
        * trigger_module_i trigger_module .clk_i .rst_ni
          * clk_i rst_ni
            * NOSUB
    * perf_counters_i perf_counters .clk_i(clk_i) .rst_ni(rst_ni)
      * clk_i rst_ni
        * NOSUB
    * controller_i controller .clk_i .rst_ni
      * clk_i rst_ni
        * NOSUB
    * i_cache_subsystem cva6_hpdcache_subsystem .clk_i(clk_i) .rst_ni(rst_ni)
      * clk_i rst_ni
        * i_cva6_icache cva6_icache .clk_i(clk_i) .rst_ni(rst_ni)
          * clk_i rst_ni
            * i_lzc lzc NOCLK NORST
              * COMB_ONLY
            * i_lfsr prim_lfsr .clk_i(clk_i) .rst_ni(rst_ni)
            * i_lzc_hit lzc NOCLK NORST
              * COMB_ONLY
            * tag_sram sram_cache .clk_i(clk_i) .rst_ni(rst_ni)
            * data_sram sram_cache .clk_i(clk_i) .rst_ni(rst_ni)
        * i_dcache cva6_hpdcache_wrapper .clk_i(clk_i) .rst_ni(rst_ni)
          * clk_i rst_ni
            * i_cva6_hpdcache_load_if_adapter .clk_i .rst_ni
            * i_cva6_hpdcache_store_if_adapter .clk_i .rst_ni
            * i_cva6_hpdcache_cmo_if_adapter .clk_i .rst_ni
            * i_hwpdf_stride_wrapper hwpf_stride_wrapper .clk_i .rst_ni
            * i_hpdcache hpdcache .clk_i .rst_ni
        * i_axi_arbiter cva6_hpdcache_subsystem_axi_arbiter .clk_i .rst_ni
          * clk_i rst_ni
            * I_icache_miss_req_fifo hpdcache_fifo_reg .clk_i .rst_ni
            * I_icache_refill_meta_fifo hpdcache_fifo_reg .clk_i .rst_ni
            * I_icache_hpdcache_data_upsize hpdcache_data_upsize .clk_i .rst_ni
            * I_mem_req_read_arbiter hpdcache_mem_req_read_arbiter .clk_i .rst_ni
            * I_mem_resp_read_demux hpdcache_mem_resp_demux .clk_i .rst_ni
            * I_hpcache_mem_to_axi_write hpdcache_mem_to_axi_write NOCLK NORST
            * I_hpdcache_mem_to_axi_read hpdcache_mem_to_axi_read NOCLK NORST
    * i_cva6_rvfi_dii_generator rvfi_dii_generator .clk_i(clk_i) .rst_ni(rst_ni)
      * PARAM_OFF
    * i_acc_dispatcher acc_dispatcher .clk_i(clk_i) .rst_ni(rst_ni)
      * PARAM_OFF
    * f_pc_fifo fifo_v3 .clk_i(clk_i) .rst_ni(rst_ni)
      * clk_i rst_ni
        * EXTERNAL
    * i_rr_arb_tree rr_arb_tree .clk_i(clk_i) .rst_ni(rst_ni)
      * clk_i rst_ni
        * EXTERNAL
    * instr_tracer_i instr_tracer .pck(clk_i) .rstn(rst_ni)
      * pck rstn
        * NOSUB
    * i_cva6_rvfi_probes cva6_rvfi_probes NOCLK NORST
      * COMB_ONLY
