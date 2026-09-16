This file lists the module instantiations within CVA6-CHERI and their clock and reset connections.
Each module instantiation is listed as <instance_name> <module_name> <clk connection> <rst connection>.
Each instantiation is then followed by the signal names of the clock and reset given in the module interface.
Note that this map is for the configuration used within mocha: [cv64a6_imafdczcheri_sv39_hpdcache_wb_config_pkg][cva6-cheri-config].
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
          * clk_i rst_ni
            * NOSUB
        * zcmt_decoder_i zcmt_decoder .clk_i(clk_i) .rst_ni(rst_ni)
          * clk_i rst_ni
            * NOSUB
        * cvxif_compressed_if_driver_i cvxif_compressed_if_driver .clk_i(clk_i) .rst_ni(rst_ni)
          * clk_i rst_ni
            * NOSUB
        * decoder_i decoder NOCLK NORST
          * COMB_ONLY
    * issue_stage_i issue_stage .clk_i .rst_ni
      * clk_i rst_ni
        * i_scoreboard scoreboard .clk_i .rst_ni
          * clk_i rst_ni
            * NOSUB
        * i_issue_read_operands .clk_i .rst_ni
          * clk_i rst_ni
            * i_cvxif_issue_register_commit_if_driver cvxif_issue_register_commit_if_driver .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
                * NOSUB
            * i_rs1_last_raw raw_checker .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
                * NOSUB
            * i_rs2_last_raw raw_checker .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
                * NOSUB
            * i_rs3_last_raw raw_checker .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
                * NOSUB
            * i_ariane_regfile_fgpa ariane_regfile_fpga .clk_i .rst_ni
              * clk_i rst_ni
                * NOSUB
            * i_ariane_regfile ariane_regfile .clk_i .rst_ni
              * clk_i rst_ni
                * NOSUB
            * i_ariane_fp_regfile_fgpa ariane_regfile_fpga .clk_i .rst_ni
              * clk_i rst_ni
                * NOSUB
            * i_ariane_fp_regfile ariane_regfile .clk_i .rst_ni
              * clk_i rst_ni
                * NOSUB
    * ex_stage_i ex_stage .clk_i(clk_i) .rst_ni(rst_ni)
      * clk_i rst_ni
        * alu_wrapper_i alu_wrapper .clk_i .rst_ni
          * clk_i rst_ni
            * alu_i alu .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
                * i_cpop_count popcount NOCLK NORST
                  * COMB_ONLY
                * i_clz_64b lzc NOCLK NORST
                  * COMB_ONLY
                * i_clz_32b lzc NOCLK NORST
                  * COMB_ONLY
            * alu2_i alu .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
                * REPEATMOD
        * branch_unit_i branch_unit .clk_i .rst_ni
          * clk_i rst_ni
            * NOSUB
        * csr_buffer_i csr_buffer .clk_i .rst_ni
          * clk_i rst_ni
            * NOSUB
        * i_mult mult .clk_i .rst_ni
          * clk_i rst_ni
            * i_multiplier multiplier .clk_i .rst_ni
              * clk_i rst_ni
                * NOSUB
            * i_div serdiv .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
                * i_lzc_a lzc NOCLK NORST
                  * COMB_ONLY
                * i_lzc_b lzc NOCLK NORST
                  * COMB_ONLY
        * fpu_i fpu_wrap .clk_i .rst_ni
          * clk_i rst_ni
            * i_fpnew_bulk fpnew_top .clk_i .rst_ni
              * NOTFOUND
        * lsu_i load_store_unit .clk_i .rst_ni
          * clk_i rst_ni
            * i_cva6_mmu cva6_mmu .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
                * i_itlb cva6_tlb .clk_i(clk_i) .rst_ni(rst_ni)
                  * clk_i rst_ni
                    * NOSUB
                * i_dtlb cva6_tlb .clk_i(clk_i) .rst_ni(rst_ni)
                  * clk_i rst_ni
                    * NOSUB
                * i_shared_tlb cva6_shared_tlb .clk_i(clk_i) .rst_ni(rst_ni)
                  * clk_i rst_ni
                    * i_lzc lzc NOCLK NORST
                      * COMB_ONLY
                    * i_lfsr prim_lfsr .clk_i(clk_i) .rst_ni(rst_ni)
                      * clk_i rst_ni
                        * EXTERNAL
                    * tag_sram sram .clk_i(clk_i) .rst_ni(rst_ni)
                      * clk_i rst_ni
                        * i_tc_sram_wrapper prim_ram_1p .clk_i(clk_i) .rst_ni(rst_ni)
                          * clk_i rst_ni
                            * EXTERNAL
                        * i_tc_sram_wrapper_user prim_ram_1p .clk_i(clk_i) .rst_ni(rst_ni)
                          * clk_i rst_ni
                            * EXTERNAL
                    * pte_sram sram .clk_i(clk_i) .rst_ni(rst_ni)
                      * clk_i rst_ni
                        * REPEATMOD
                * i_ptw cva6_ptw .clk_i(clk_i) .rst_ni(rst_ni)
                  * i_pmp_ptw pmp NOCLK NORST
                    * COMB_ONLY
            * i_pmp_data_if pmp_data_if .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
                * i_pmp_if pmp NOCLK NORST
                  * COMB_ONLY
                * i_pmp_data pmp NOCLK NORST
                  * COMB_ONLY
            * i_store_unit store_unit .clk_i .rst_ni
              * clk_i rst_ni
                * store_buffer_i store_buffer .clk_i .rst_ni
                  * clk_i rst_ni
                    * NOSUB
                * i_amo_buffer amo_buffer .clk_i .rst_ni
                  * clk_i rst_ni
                    * i_amo_fifo cva6_fifo_v3 .clk_i(clk_i) .rst_ni(rst_ni)
                      * clk_i rst_ni
                        * REPEATMOD
            * i_load_unit load_unit .clk_i .rst_ni
              * clk_i rst_ni
                * lzc_windex_i lzc NOCLK NORST
                  * COMB_ONLY
            * i_pipe_reg_load shift_reg .clk_i .rst_ni
              * NOTFOUND
            * i_pipe_reg_store shift_reg .clk_i .rst_ni
              * NOTFOUND
            * lsu_bypass_i lsu_bypass .clk_i .rst_ni
              * clk_i rst_ni
                * NOSUB
        * cvxif_fu_i cvxif_fu .clk_i .rst_ni
          * clk_i rst_ni
            * NOSUB
        * clu_i cheri_unit .clk_i .rst_ni
          * clk_i rst_ni
            * NOSUB
        * aes_i aes .clk_i .rst_ni
          * clk_i rst_ni
            * NOSUB
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
              * clk_i rst_ni
                * EXTERNAL
            * i_lzc_hit lzc NOCLK NORST
              * COMB_ONLY
            * tag_sram sram_cache .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
                * i_tc_sram_wrapper tc_sram_wrapper_cache_techno .clk_i(clk_i) .rst_ni(rst_ni)
                  * clk_i rst_ni
                    * i_tc_sram tc_sram .clk_i(clk_i) .rst_ni(rst_ni)
                      * NOTFOUND
                * i_tc_sram_wrapper tc_sram_wrapper_cache_techno .clk_i(clk_i) .rst_ni(rst_ni)
                  * clk_i rst_ni
                    * REPEATMOD
                * data_sram sram .clk_i(clk_i) .rst_ni(rst_ni)
                  * clk_i rst_ni
                    * REPEATMOD
            * data_sram sram_cache .clk_i(clk_i) .rst_ni(rst_ni)
              * clk_i rst_ni
                * REPEATMOD
        * i_dcache cva6_hpdcache_wrapper .clk_i(clk_i) .rst_ni(rst_ni)
          * clk_i rst_ni
            * i_cva6_hpdcache_load_if_adapter cva6_hpdcache_if_adapter .clk_i .rst_ni
              * clk_i rst_ni
                * NOSUB
            * i_cva6_hpdcache_store_if_adapter cva6_hpdcache_if_adapter .clk_i .rst_ni
              * clk_i rst_ni
                * NOSUB
            * i_cva6_hpdcache_cmo_if_adapter cva6_hpdcache_cmo_if_adapter .clk_i .rst_ni
              * PARAM_OFF
            * i_hwpf_stride_wrapper hwpf_stride_wrapper hwpf_stride_wrapper .clk_i .rst_ni
              * clk_i rst_ni
                * EXTERNAL
            * i_hpdcache hpdcache .clk_i .rst_ni
              * clk_i rst_ni
                * EXTERNAL
        * i_axi_arbiter cva6_hpdcache_subsystem_axi_arbiter .clk_i .rst_ni
          * clk_i rst_ni
            * i_icache_miss_req_fifo hpdcache_fifo_reg .clk_i .rst_ni
              * clk_i rst_ni
                * EXTERNAL
            * i_icache_refill_meta_fifo hpdcache_fifo_reg .clk_i .rst_ni
              * clk_i rst_ni
                * EXTERNAL
            * i_icache_hpdcache_data_upsize hpdcache_data_upsize .clk_i .rst_ni
              * clk_i rst_ni
                * EXTERNAL
            * i_mem_req_read_arbiter hpdcache_mem_req_read_arbiter .clk_i .rst_ni
              * clk_i rst_ni
                * EXTERNAL
            * i_mem_resp_read_demux hpdcache_mem_resp_demux .clk_i .rst_ni
              * clk_i rst_ni
                * EXTERNAL
            * i_hpcache_mem_to_axi_write hpdcache_mem_to_axi_write NOCLK NORST
              * COMB_ONLY
            * i_hpdcache_mem_to_axi_read hpdcache_mem_to_axi_read NOCLK NORST
              * COMB_ONLY
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

[cva6-cheri-config]: ../../hw/vendor/cva6_cheri/core/include/cv64a6_imafdczcheri_sv39_hpdcache_wb_config_pkg.sv
