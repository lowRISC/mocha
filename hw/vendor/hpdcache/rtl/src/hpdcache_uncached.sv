/*
 *  Copyright 2023 CEA*
 *  *Commissariat a l'Energie Atomique et aux Energies Alternatives (CEA)
 *  Copyright 2025 Inria, Universite Grenoble-Alpes, TIMA
 *
 *  SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
 *
 *  Licensed under the Solderpad Hardware License v 2.1 (the “License”); you
 *  may not use this file except in compliance with the License, or, at your
 *  option, the Apache License version 2.0. You may obtain a copy of the
 *  License at
 *
 *  https://solderpad.org/licenses/SHL-2.1/
 *
 *  Unless required by applicable law or agreed to in writing, any work
 *  distributed under the License is distributed on an “AS IS” BASIS, WITHOUT
 *  WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
 *  License for the specific language governing permissions and limitations
 *  under the License.
 */
/*
 *  Authors       : Cesar Fuguet
 *  Creation Date : May, 2021
 *  Description   : HPDcache uncached and AMO request handler
 *  History       :
 */
module hpdcache_uncached
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter hpdcache_cfg_t HPDcacheCfg = '0,

    parameter type hpdcache_nline_t = logic,
    parameter type hpdcache_tag_t = logic,
    parameter type hpdcache_set_t = logic,
    parameter type hpdcache_offset_t = logic,
    parameter type hpdcache_word_t = logic,

    parameter type hpdcache_req_addr_t = logic,
    parameter type hpdcache_req_tid_t = logic,
    parameter type hpdcache_req_sid_t = logic,
    parameter type hpdcache_req_user_t = logic,
    parameter type hpdcache_req_data_t = logic,
    parameter type hpdcache_req_be_t = logic,

    parameter type hpdcache_way_vector_t = logic,

    parameter type hpdcache_req_t = logic,
    parameter type hpdcache_rsp_t = logic,
    parameter type hpdcache_mem_id_t = logic,
    parameter type hpdcache_mem_req_t = logic,
    parameter type hpdcache_mem_req_w_t = logic,
    parameter type hpdcache_mem_resp_r_t = logic,
    parameter type hpdcache_mem_resp_w_t = logic
)
    //  }}}

    //  Ports
    //  {{{
(
    input  logic                  clk_i,
    input  logic                  rst_ni,

    //  Global control signals
    //  {{{
    input  logic                  wbuf_empty_i,
    input  logic                  mshr_empty_i,
    input  logic                  rtab_empty_i,
    input  logic                  ctrl_empty_i,
    input  logic                  flush_empty_i,
    //  }}}

    //  Cache-side request interface
    //  {{{
    input  logic                  req_valid_i,
    output logic                  req_ready_o,
    input  hpdcache_uc_op_t       req_op_i,
    input  hpdcache_req_addr_t    req_addr_i,
    input  hpdcache_req_size_t    req_size_i,
    input  hpdcache_req_data_t    req_data_i,
    input  hpdcache_req_user_t    req_user_i,
    input  hpdcache_req_be_t      req_be_i,
    input  logic                  req_uc_i,
    input  hpdcache_req_sid_t     req_sid_i,
    input  hpdcache_req_tid_t     req_tid_i,
    input  logic                  req_need_rsp_i,
    //  }}}

    //  Write buffer interface
    //  {{{
    output logic                  wbuf_flush_all_o,
    //  }}}

    //  AMO Cache Interface
    //  {{{
    output logic                  dir_amo_match_o,
    output hpdcache_set_t         dir_amo_match_set_o,
    output hpdcache_tag_t         dir_amo_match_tag_o,
    output logic                  dir_amo_updt_sel_victim_o,
    input  hpdcache_way_vector_t  dir_amo_hit_way_i,

    output logic                  data_amo_write_o,
    output logic                  data_amo_write_enable_o,
    output hpdcache_set_t         data_amo_write_set_o,
    output hpdcache_req_size_t    data_amo_write_size_o,
    output hpdcache_word_t        data_amo_write_word_o,
    output hpdcache_req_user_t    data_amo_write_user_o,
    output hpdcache_req_data_t    data_amo_write_data_o,
    output hpdcache_req_be_t      data_amo_write_be_o,
    // }}}

    //  LR/SC reservation buffer
    //  {{{
    input  logic                  lrsc_snoop_i,
    input  hpdcache_req_addr_t    lrsc_snoop_addr_i,
    input  hpdcache_req_size_t    lrsc_snoop_size_i,
    //  }}}

    //  Core response interface
    //  {{{
    input  logic                  core_rsp_ready_i,
    output logic                  core_rsp_valid_o,
    output hpdcache_rsp_t         core_rsp_o,
    //  }}}

    //  MEMORY interfaces
    //  {{{
    //      Memory request unique identifier
    input  hpdcache_mem_id_t      mem_read_id_i,
    input  hpdcache_mem_id_t      mem_write_id_i,

    //      Read interface
    input  logic                  mem_req_read_ready_i,
    output logic                  mem_req_read_valid_o,
    output hpdcache_mem_req_t     mem_req_read_o,

    output logic                  mem_resp_read_ready_o,
    input  logic                  mem_resp_read_valid_i,
    input  hpdcache_mem_resp_r_t  mem_resp_read_i,

    //      Write interface
    input  logic                  mem_req_write_ready_i,
    output logic                  mem_req_write_valid_o,
    output hpdcache_mem_req_t     mem_req_write_o,

    input  logic                  mem_req_write_data_ready_i,
    output logic                  mem_req_write_data_valid_o,
    output hpdcache_mem_req_w_t   mem_req_write_data_o,

    output logic                  mem_resp_write_ready_o,
    input  logic                  mem_resp_write_valid_i,
    input  hpdcache_mem_resp_w_t  mem_resp_write_i,
    //  }}}

    //  Configuration interface
    //  {{{
    input  logic                  cfg_error_on_cacheable_amo_i
    //  }}}
);
    //  }}}

//  Definition of constants and types
//  {{{
    localparam hpdcache_uint MEM_REQ_RATIO = HPDcacheCfg.u.memDataWidth/HPDcacheCfg.reqDataWidth;
    localparam hpdcache_uint MEM_REQ_WORD_INDEX_WIDTH = $clog2(MEM_REQ_RATIO);
    localparam hpdcache_uint REQ_MEM_RATIO = HPDcacheCfg.reqDataWidth/HPDcacheCfg.u.memDataWidth;
    localparam hpdcache_uint REQ_MEM_WORD_INDEX_WIDTH = $clog2(REQ_MEM_RATIO);

    typedef enum {
        UC_IDLE,
        UC_WAIT_PENDING,
        UC_MEM_REQ,
        UC_MEM_W_REQ,
        UC_MEM_WDATA_REQ,
        UC_MEM_W_AND_WDATA2_REQ,
        UC_MEM_WDATA2_REQ,
        UC_MEM_WAIT_RSP,
        UC_CORE_RSP,
        UC_AMO_READ_DIR,
        UC_AMO_WRITE_DATA
    } hpdcache_uc_fsm_t;

    localparam logic AMO_SC_SUCCESS = 1'b0;
    localparam logic AMO_SC_FAILURE = 1'b1;

    function automatic logic [HPDcacheCfg.amoWidth-1:0] prepare_amo_data_operand(
            input logic [HPDcacheCfg.amoWidth-1:0] data_i,
            input hpdcache_req_size_t   size_i,
            input hpdcache_req_addr_t   addr_i,
            input logic                 sign_extend_i
    );
        localparam AMO_WIDTH_MSB_SELECT = $clog2(HPDcacheCfg.amoWidth/8)-1;
        // 128-bits AMOs are already aligned, thus do nothing
        if (size_i == hpdcache_req_size_t'(4)) begin
            return data_i;
        end

        // 64-bits AMOs: never sign extend into the metadata
        else if (size_i == hpdcache_req_size_t'(3)) begin
            localparam hpdcache_uint dword_count = HPDcacheCfg.amoWidth / 64;
            automatic logic[dword_count-1:0][63:0] dwords;
            automatic logic[63:0] shifted_dword;
            for (int i = 0; i < dword_count; i = i+1) begin
                dwords[i] = data_i[i*64+:64];
            end
            shifted_dword = dword_count > 1 ? dwords[addr_i[hpdcache_max(AMO_WIDTH_MSB_SELECT,3):3]] : dwords[0];
            return {{64{1'b0}}, shifted_dword};
        end

        // 32-bits AMOs
        else if (size_i == hpdcache_req_size_t'(2)) begin
            localparam hpdcache_uint word_count = HPDcacheCfg.amoWidth / 32;
            automatic logic[word_count-1:0][31:0] words;
            automatic logic[31:0] shifted_word;
            for (int i = 0; i < word_count; i = i+1) begin
                words[i] = data_i[i*32+:32];
            end
            shifted_word = words[addr_i[AMO_WIDTH_MSB_SELECT:2]];
            return {{64{1'b0}}, {32{sign_extend_i & shifted_word[31]}}, shifted_word};
        end

        // 16-bits AMOs
        else if (size_i == hpdcache_req_size_t'(1)) begin
            localparam hpdcache_uint hword_count = HPDcacheCfg.amoWidth / 16;
            automatic logic[hword_count-1:0][15:0] hwords;
            automatic logic[15:0] shifted_hword;
            for (int i = 0; i < hword_count; i = i+1) begin
                hwords[i] = data_i[i*16+:16];
            end
            shifted_hword = hwords[addr_i[AMO_WIDTH_MSB_SELECT:1]];
            return {{64{1'b0}}, {48{sign_extend_i & shifted_hword[15]}}, shifted_hword};
        end

        // 8-bits AMOs
        else begin
            localparam hpdcache_uint byte_count = HPDcacheCfg.amoWidth / 8;
            automatic logic[byte_count-1:0][7:0] bytes;
            automatic logic[7:0] shifted_byte;
            for (int i = 0; i < byte_count; i = i+1) begin
                bytes[i] = data_i[i*8+:8];
            end
            shifted_byte = bytes[addr_i[AMO_WIDTH_MSB_SELECT:0]];
            return {{64{1'b0}}, {56{sign_extend_i & shifted_byte[7]}}, shifted_byte};
        end
    endfunction;

    function automatic logic [HPDcacheCfg.amoWidth-1:0] prepare_amo_data_result(
            input logic [HPDcacheCfg.amoWidth-1:0] data_i,
            input hpdcache_req_size_t   size_i
    );
        // 128-bits AMOs are already aligned, thus do nothing
        if (size_i == hpdcache_req_size_t'(4)) begin
            return data_i;
        end

        // 64-bits AMOs
        else if (size_i == hpdcache_req_size_t'(3)) begin
            return {2{data_i[63:0]}};
        end

        // 32-bits AMOs
        else if (size_i == hpdcache_req_size_t'(2)) begin
            return {4{data_i[31:0]}};
        end

        // 16-bits AMOs
        else if (size_i == hpdcache_req_size_t'(1)) begin
            return {8{data_i[15:0]}};
        end

        // 8-bits AMOs
        else begin
            return {16{data_i[7:0]}};
        end
    endfunction;

    function automatic logic amo_need_sign_extend(hpdcache_uc_op_t op);
        unique case (1'b1)
            op.is_amo_add,
            op.is_amo_max,
            op.is_amo_min: return 1'b1;
            default      : return 1'b0;
        endcase;
    endfunction
//  }}}

//  Internal signals and registers
//  {{{
    hpdcache_uc_fsm_t   uc_fsm_q, uc_fsm_d;
    hpdcache_uc_op_t    req_op_q;
    hpdcache_req_addr_t req_addr_q;
    hpdcache_req_size_t req_size_q;
    hpdcache_req_data_t req_data_q;
    hpdcache_req_user_t req_user_q;
    hpdcache_req_be_t   req_be_q;
    logic               req_uc_q;
    hpdcache_req_sid_t  req_sid_q;
    hpdcache_req_tid_t  req_tid_q;
    logic               req_need_rsp_q;
    logic               multiflit;
    logic               req_is_cap;
    logic               no_pend_trans;

    logic               uc_sc_retcode_q, uc_sc_retcode_d;

    hpdcache_req_data_t rsp_rdata_q, rsp_rdata_d;
    hpdcache_req_user_t rsp_ruser_q, rsp_ruser_d;
    logic               rsp_error_set, rsp_error_rst;
    logic               rsp_error_q;
    logic               mem_resp_write_valid_q, mem_resp_write_valid_d;
    logic               mem_resp_read_valid_q, mem_resp_read_valid_d;
    logic               mem_resp_read_finishing;

    hpdcache_req_data_t   mem_req_write_data;
    hpdcache_req_user_t   mem_req_write_user;

    logic [HPDcacheCfg.amoWidth-1:0] amo_req_ld_data;
    logic                            amo_req_ld_user;
    logic [HPDcacheCfg.amoWidth-1:0] amo_ld_data;
    logic                            amo_ld_user;
    logic [HPDcacheCfg.amoWidth-1:0] amo_req_st_data;
    logic                            amo_req_st_user;
    logic [HPDcacheCfg.amoWidth-1:0] amo_st_data;
    logic                            amo_st_user;
    logic [HPDcacheCfg.amoWidth-1:0] amo_result_data;
    logic                            amo_result_user;
    logic [HPDcacheCfg.amoWidth-1:0] amo_write_data;
    logic                            amo_write_user;
//  }}}

//  LR/SC reservation buffer logic
//  {{{
    logic               lrsc_rsrv_valid_q;
    hpdcache_req_addr_t lrsc_rsrv_addr_q, lrsc_rsrv_addr_d;
    hpdcache_nline_t    lrsc_rsrv_nline;
    hpdcache_offset_t   lrsc_rsrv_word;

    hpdcache_offset_t   lrsc_snoop_words;
    hpdcache_nline_t    lrsc_snoop_nline;
    hpdcache_offset_t   lrsc_snoop_base, lrsc_snoop_end;
    logic               lrsc_snoop_hit;
    logic               lrsc_snoop_reset;

    hpdcache_nline_t    lrsc_uc_nline;
    hpdcache_offset_t   lrsc_uc_word;
    logic               lrsc_uc_hit;
    logic               lrsc_uc_set, lrsc_uc_reset;

    //  NOTE: Reservation set for LR instruction is always 16-bytes in this
    //  implementation.
    assign lrsc_rsrv_nline  = lrsc_rsrv_addr_q[HPDcacheCfg.clOffsetWidth +:
                                               HPDcacheCfg.nlineWidth];
    assign lrsc_rsrv_word   = lrsc_rsrv_addr_q[0 +: HPDcacheCfg.clOffsetWidth] >> 4;

    //  Check hit on LR/SC reservation for snoop port (normal write accesses)
    assign lrsc_snoop_words = (lrsc_snoop_size_i < 4) ?
            1 : hpdcache_offset_t'((8'h1 << lrsc_snoop_size_i) >> 4);
    assign lrsc_snoop_nline = lrsc_snoop_addr_i[HPDcacheCfg.clOffsetWidth +:
                                                HPDcacheCfg.nlineWidth];
    assign lrsc_snoop_base  = lrsc_snoop_addr_i[0 +: HPDcacheCfg.clOffsetWidth] >> 4;
    assign lrsc_snoop_end   = lrsc_snoop_base + lrsc_snoop_words;

    assign lrsc_snoop_hit   = lrsc_rsrv_valid_q & (lrsc_rsrv_nline == lrsc_snoop_nline) &
                                                  (lrsc_rsrv_word  >= lrsc_snoop_base) &
                                                  (lrsc_rsrv_word  <  lrsc_snoop_end );

    assign lrsc_snoop_reset = lrsc_snoop_i & lrsc_snoop_hit;

    //  Check hit on LR/SC reservation for AMOs and SC
    assign lrsc_uc_nline    = req_addr_i[HPDcacheCfg.clOffsetWidth +: HPDcacheCfg.nlineWidth];
    assign lrsc_uc_word     = req_addr_i[0 +: HPDcacheCfg.clOffsetWidth] >> 4;

    assign lrsc_uc_hit      = lrsc_rsrv_valid_q & (lrsc_rsrv_nline == lrsc_uc_nline) &
                                                  (lrsc_rsrv_word  == lrsc_uc_word);
//  }}}

    assign no_pend_trans = wbuf_empty_i &&
                           mshr_empty_i &&
                           rtab_empty_i &&
                           ctrl_empty_i &&
                           flush_empty_i;

    assign multiflit = HPDcacheCfg.u.capAmoEn && req_size_q == hpdcache_req_size_t'(4);
    assign req_is_cap = HPDcacheCfg.u.capAmoEn && HPDcacheCfg.u.userEn && req_size_q == hpdcache_req_size_t'(4);
    assign mem_resp_read_finishing = mem_resp_read_valid_i && mem_resp_read_i.mem_resp_r_last;

//  Uncacheable request FSM
//  {{{
    always_comb
    begin : uc_fsm_comb
        mem_resp_write_valid_d = mem_resp_write_valid_q;
        mem_resp_read_valid_d  = mem_resp_read_valid_q;
        rsp_error_set          = 1'b0;
        rsp_error_rst          = 1'b0;
        lrsc_rsrv_addr_d       = lrsc_rsrv_addr_q;
        uc_sc_retcode_d        = uc_sc_retcode_q;
        wbuf_flush_all_o       = 1'b0;
        lrsc_uc_set            = 1'b0;
        lrsc_uc_reset          = 1'b0;

        uc_fsm_d               = uc_fsm_q;

        unique case (uc_fsm_q)
            //  Wait for a request
            //  {{{
            UC_IDLE: begin

                if (req_valid_i) begin
                    wbuf_flush_all_o = 1'b1;

                    unique case (1'b1)
                        req_op_i.is_ld,
                        req_op_i.is_st: begin
                            if (no_pend_trans) begin
                                uc_fsm_d = UC_MEM_REQ;
                            end else begin
                                uc_fsm_d = UC_WAIT_PENDING;
                            end
                        end

                        req_op_i.is_amo_swap,
                        req_op_i.is_amo_add,
                        req_op_i.is_amo_and,
                        req_op_i.is_amo_or,
                        req_op_i.is_amo_xor,
                        req_op_i.is_amo_max,
                        req_op_i.is_amo_maxu,
                        req_op_i.is_amo_min,
                        req_op_i.is_amo_minu,
                        req_op_i.is_amo_lr: begin
                            //  Reset LR/SC reservation if AMO matches its address
                            lrsc_uc_reset = ~req_op_i.is_amo_lr & lrsc_uc_hit;

                            if (!req_uc_i && cfg_error_on_cacheable_amo_i) begin
                                rsp_error_set = 1'b1;
                                uc_fsm_d = UC_CORE_RSP;
                            end else begin
                                if (no_pend_trans) begin
                                    uc_fsm_d = UC_MEM_REQ;
                                end else begin
                                    uc_fsm_d = UC_WAIT_PENDING;
                                end
                            end
                        end

                        req_op_i.is_amo_sc: begin
                            if (!req_uc_i && cfg_error_on_cacheable_amo_i) begin
                                rsp_error_set = 1'b1;
                                uc_fsm_d = UC_CORE_RSP;
                            end else begin
                                //  Reset previous reservation (if any)
                                lrsc_uc_reset = 1'b1;

                                //  SC with valid reservation
                                if (lrsc_uc_hit) begin
                                    if (no_pend_trans) begin
                                        uc_fsm_d = UC_MEM_REQ;
                                    end else begin
                                        uc_fsm_d = UC_WAIT_PENDING;
                                    end
                                end
                                //  SC with no valid reservation, thus respond with the failure code
                                else begin
                                    uc_sc_retcode_d = AMO_SC_FAILURE;
                                    uc_fsm_d = UC_CORE_RSP;
                                end
                            end
                        end

                        default: begin
                            if (req_need_rsp_i) begin
                                rsp_error_set = 1'b1;
                                uc_fsm_d = UC_CORE_RSP;
                            end
                        end
                    endcase
                end
            end
            //  }}}

            //  Wait for all pending transactions to be completed
            //  {{{
            UC_WAIT_PENDING: begin
                if (no_pend_trans) begin
                    uc_fsm_d = UC_MEM_REQ;
                end else begin
                    uc_fsm_d = UC_WAIT_PENDING;
                end
            end
            //  }}}

            //  Send request to memory
            //  {{{
            UC_MEM_REQ: begin
                uc_fsm_d = UC_MEM_REQ;

                mem_resp_write_valid_d = 1'b0;
                mem_resp_read_valid_d  = 1'b0;

                unique case (1'b1)
                    req_op_q.is_ld,
                    req_op_q.is_amo_lr: begin
                        if (mem_req_read_ready_i) begin
                            uc_fsm_d = UC_MEM_WAIT_RSP;
                        end
                    end

                    req_op_q.is_st,
                    req_op_q.is_amo_sc,
                    req_op_q.is_amo_swap,
                    req_op_q.is_amo_add,
                    req_op_q.is_amo_and,
                    req_op_q.is_amo_or,
                    req_op_q.is_amo_xor,
                    req_op_q.is_amo_max,
                    req_op_q.is_amo_maxu,
                    req_op_q.is_amo_min,
                    req_op_q.is_amo_minu: begin
                        if (mem_req_write_ready_i && mem_req_write_data_ready_i) begin
                            uc_fsm_d = multiflit ? UC_MEM_WDATA2_REQ : UC_MEM_WAIT_RSP;
                        end else if (mem_req_write_ready_i) begin
                            uc_fsm_d = UC_MEM_WDATA_REQ;
                        end else if (mem_req_write_data_ready_i) begin
                            uc_fsm_d = multiflit ? UC_MEM_W_AND_WDATA2_REQ : UC_MEM_W_REQ;
                        end
                    end
                endcase
            end
            //  }}}

            //  Send write address
            //  {{{
            UC_MEM_W_REQ: begin
                mem_resp_write_valid_d = mem_resp_write_valid_q | mem_resp_write_valid_i;
                mem_resp_read_valid_d = mem_resp_read_valid_q | mem_resp_read_finishing;

                if (mem_req_write_ready_i) begin
                    uc_fsm_d = UC_MEM_WAIT_RSP;
                end else begin
                    uc_fsm_d = UC_MEM_W_REQ;
                end
            end
            //  }}}

            //  Send write address and second write data flit
            //  {{{
            UC_MEM_W_AND_WDATA2_REQ: begin
                mem_resp_write_valid_d = mem_resp_write_valid_q | mem_resp_write_valid_i;
                mem_resp_read_valid_d = mem_resp_read_valid_q | mem_resp_read_finishing;

                if (mem_req_write_ready_i && mem_req_write_data_ready_i) begin
                    uc_fsm_d = UC_MEM_WAIT_RSP;
                end else if (mem_req_write_ready_i) begin
                    uc_fsm_d = UC_MEM_WDATA2_REQ;
                end else if (mem_req_write_data_ready_i) begin
                    uc_fsm_d = UC_MEM_W_REQ;
                end else begin
                    uc_fsm_d = UC_MEM_W_AND_WDATA2_REQ;
                end
            end
            //  }}}

            //  Send write data
            //  {{{
            UC_MEM_WDATA_REQ: begin
                mem_resp_write_valid_d = mem_resp_write_valid_q | mem_resp_write_valid_i;
                mem_resp_read_valid_d = mem_resp_read_valid_q | mem_resp_read_finishing;

                if (mem_req_write_data_ready_i) begin
                    uc_fsm_d = multiflit ? UC_MEM_WDATA2_REQ : UC_MEM_WAIT_RSP;
                end else begin
                    uc_fsm_d = UC_MEM_WDATA_REQ;
                end
            end
            //  }}}
            //  Send second flit of write data
            //  {{{
            UC_MEM_WDATA2_REQ: begin
                mem_resp_write_valid_d = mem_resp_write_valid_q | mem_resp_write_valid_i;
                mem_resp_read_valid_d = mem_resp_read_valid_q | mem_resp_read_finishing;

                if (mem_req_write_data_ready_i) begin
                    uc_fsm_d = UC_MEM_WAIT_RSP;
                end else begin
                    uc_fsm_d = UC_MEM_WDATA_REQ;
                end
            end
            //  }}}

            //  Wait for the response from the memory
            //  {{{
            UC_MEM_WAIT_RSP: begin
                automatic bit rd_error;
                automatic bit wr_error;

                uc_fsm_d = UC_MEM_WAIT_RSP;
                mem_resp_write_valid_d = mem_resp_write_valid_q | mem_resp_write_valid_i;
                mem_resp_read_valid_d = mem_resp_read_valid_q | mem_resp_read_finishing;

                rd_error = mem_resp_read_finishing  &&
                           ( mem_resp_read_i.mem_resp_r_error == HPDCACHE_MEM_RESP_NOK);
                wr_error = mem_resp_write_valid_i &&
                           (mem_resp_write_i.mem_resp_w_error == HPDCACHE_MEM_RESP_NOK);
                rsp_error_set = req_need_rsp_q & (rd_error | wr_error);

                unique case (1'b1)
                    req_op_q.is_ld: begin
                        if (mem_resp_read_finishing) begin
                            if (req_need_rsp_q) begin
                                uc_fsm_d = UC_CORE_RSP;
                            end else begin
                                uc_fsm_d = UC_IDLE;
                            end
                        end
                    end
                    req_op_q.is_st: begin
                        if (mem_resp_write_valid_i) begin
                            if (req_need_rsp_q) begin
                                uc_fsm_d = UC_CORE_RSP;
                            end else begin
                                uc_fsm_d = UC_IDLE;
                            end
                        end
                    end
                    req_op_q.is_amo_lr: begin
                        if (mem_resp_read_finishing) begin
                            //  set a new reservation
                            if (!rd_error)
                            begin
                                lrsc_uc_set      = 1'b1;
                                lrsc_rsrv_addr_d = req_addr_q;
                            end
                            //  in case of a memory error, do not make the reservation and
                            //  invalidate an existing one (if valid)
                            else begin
                                lrsc_uc_reset = 1'b1;
                            end

                            if (req_uc_q || rd_error) begin
                                uc_fsm_d = UC_CORE_RSP;
                            end else begin
                                uc_fsm_d = UC_AMO_READ_DIR;
                            end
                        end
                    end
                    req_op_q.is_amo_sc: begin
                        if (mem_resp_write_valid_i) begin
                            automatic bit is_atomic;

                            is_atomic = mem_resp_write_i.mem_resp_w_is_atomic && !wr_error;
                            uc_sc_retcode_d = is_atomic ? AMO_SC_SUCCESS : AMO_SC_FAILURE;

                            if (req_uc_q || !is_atomic) begin
                                uc_fsm_d = UC_CORE_RSP;
                            end else begin
                                uc_fsm_d = UC_AMO_READ_DIR;
                            end
                        end
                    end
                    req_op_q.is_amo_swap,
                    req_op_q.is_amo_add,
                    req_op_q.is_amo_and,
                    req_op_q.is_amo_or,
                    req_op_q.is_amo_xor,
                    req_op_q.is_amo_max,
                    req_op_q.is_amo_maxu,
                    req_op_q.is_amo_min,
                    req_op_q.is_amo_minu: begin
                        //  wait for both old data and write acknowledged were received
                        if ((mem_resp_read_finishing && mem_resp_write_valid_i) ||
                            (mem_resp_read_finishing && mem_resp_write_valid_q) ||
                            (mem_resp_read_valid_q && mem_resp_write_valid_i))
                        begin
                            if (req_uc_q || rsp_error_q || rd_error || wr_error) begin
                                uc_fsm_d = UC_CORE_RSP;
                            end else begin
                                uc_fsm_d = UC_AMO_READ_DIR;
                            end
                        end
                    end
                endcase
            end
            //  }}}

            //  Send the response to the requester
            //  {{{
            UC_CORE_RSP: begin
                if (core_rsp_ready_i) begin
                    rsp_error_rst = 1'b1;
                    uc_fsm_d = UC_IDLE;
                end else begin
                    uc_fsm_d = UC_CORE_RSP;
                end
            end
            //  }}}

            //  Check for a cache hit on the AMO target address
            //  {{{
            UC_AMO_READ_DIR: begin
                uc_fsm_d = UC_AMO_WRITE_DATA;
            end
            //  }}}

            //  Write the locally computed AMO result in the cache
            //  {{{
            UC_AMO_WRITE_DATA: begin
                uc_fsm_d = UC_CORE_RSP;
            end
            //  }}}
        endcase
    end
//  }}}

//  AMO unit
//  {{{

    if (HPDcacheCfg.reqDataWidth > HPDcacheCfg.amoWidth) begin : gen_amo_data_width_gt_amo_width
        localparam hpdcache_uint AMO_WORD_INDEX_WIDTH = $clog2(HPDcacheCfg.reqDataWidth/HPDcacheCfg.amoWidth);
        hpdcache_mux #(
            .NINPUT         (HPDcacheCfg.reqDataWidth/HPDcacheCfg.amoWidth),
            .DATA_WIDTH     (HPDcacheCfg.amoWidth),
            .ONE_HOT_SEL    (1'b0)
        ) amo_ld_data_mux_i (
            .data_i         (rsp_rdata_q),
            .sel_i          (req_addr_q[$clog2(HPDcacheCfg.amoWidth/8) +: AMO_WORD_INDEX_WIDTH]),
            .data_o         (amo_req_ld_data)
        );

        if (HPDcacheCfg.u.userEn) begin : gen_amo_req_ld_user_userEn
            hpdcache_mux #(
                .NINPUT         (HPDcacheCfg.reqDataWidth/HPDcacheCfg.amoWidth),
                .DATA_WIDTH     (1),
                .ONE_HOT_SEL    (1'b0)
            ) amo_ld_data_mux_i (
                .data_i         (rsp_ruser_q),
                .sel_i          (req_addr_q[$clog2(HPDcacheCfg.amoWidth/8) +: AMO_WORD_INDEX_WIDTH]),
                .data_o         (amo_req_ld_user)
            );
        end else begin : gen_amo_req_ld_user_default
            assign amo_req_ld_user = '0;
        end

        hpdcache_mux #(
            .NINPUT         (HPDcacheCfg.reqDataWidth/HPDcacheCfg.amoWidth),
            .DATA_WIDTH     (HPDcacheCfg.amoWidth),
            .ONE_HOT_SEL    (1'b0)
        ) amo_st_data_mux_i (
            .data_i         (req_data_q),
            .sel_i          (req_addr_q[$clog2(HPDcacheCfg.amoWidth/8) +: AMO_WORD_INDEX_WIDTH]),
            .data_o         (amo_req_st_data)
        );

        if (HPDcacheCfg.u.userEn) begin : gen_amo_req_st_user_userEn
            hpdcache_mux #(
                .NINPUT         (HPDcacheCfg.reqDataWidth/HPDcacheCfg.amoWidth),
                .DATA_WIDTH     (1),
                .ONE_HOT_SEL    (1'b0)
            ) amo_ld_data_mux_i (
                .data_i         (req_user_q),
                .sel_i          (req_addr_q[$clog2(HPDcacheCfg.amoWidth/8) +: AMO_WORD_INDEX_WIDTH]),
                .data_o         (amo_req_st_user)
            );
        end else begin : gen_amo_req_st_user_default
            assign amo_req_st_user = '0;
        end
    end else begin : gen_amo_data_width_leq_amo_width
        assign amo_req_ld_data = rsp_rdata_q;
        assign amo_req_ld_user = HPDcacheCfg.u.userEn ? rsp_ruser_q : '0;
        assign amo_req_st_data = req_data_q;
        assign amo_req_st_user = HPDcacheCfg.u.userEn ? req_user_q : '0;
    end

    assign amo_ld_data = prepare_amo_data_operand(amo_req_ld_data, req_size_q,
            req_addr_q, amo_need_sign_extend(req_op_q));
    assign amo_ld_user = req_is_cap ? amo_req_ld_user : '0;
    assign amo_st_data = prepare_amo_data_operand(amo_req_st_data, req_size_q,
            req_addr_q, amo_need_sign_extend(req_op_q));
    assign amo_st_user = req_is_cap ? amo_req_st_user : '0;

    hpdcache_amo #(
        .DATA_WIDTH  (HPDcacheCfg.amoWidth),
        .ARITH_WIDTH (64),
        .user_t      (hpdcache_req_user_t),
        .userEn      (HPDcacheCfg.u.userEn)
    ) amo_unit_i (
        .ld_data_i   (amo_ld_data),
        .ld_user_i   (amo_ld_user),
        .st_data_i   (amo_st_data),
        .st_user_i   (amo_st_user),
        .op_i        (req_op_q),
        .result_o    (amo_result_data),
        .user_o      (amo_result_user)
    );

    assign dir_amo_match_o = (uc_fsm_q == UC_AMO_READ_DIR);
    assign dir_amo_match_set_o = req_addr_q[HPDcacheCfg.clOffsetWidth +: HPDcacheCfg.setWidth];
    assign dir_amo_match_tag_o = req_addr_q[(HPDcacheCfg.clOffsetWidth + HPDcacheCfg.setWidth) +:
                                            HPDcacheCfg.tagWidth];
    assign dir_amo_updt_sel_victim_o = (uc_fsm_q == UC_AMO_WRITE_DATA);

    assign data_amo_write_o = (uc_fsm_q == UC_AMO_WRITE_DATA);
    assign data_amo_write_enable_o = |dir_amo_hit_way_i;
    assign data_amo_write_set_o = req_addr_q[HPDcacheCfg.clOffsetWidth +: HPDcacheCfg.setWidth];
    assign data_amo_write_size_o = req_size_q;
    assign data_amo_write_word_o = req_addr_q[HPDcacheCfg.wordByteIdxWidth +:
                                              HPDcacheCfg.clWordIdxWidth];
    assign data_amo_write_be_o = req_be_q;

    assign amo_write_data = prepare_amo_data_result(amo_result_data, req_size_q);
    assign amo_write_user = req_is_cap ? amo_result_user : '0;
    if (HPDcacheCfg.reqDataWidth >= HPDcacheCfg.amoWidth) begin : gen_amo_ram_write_data_ge_amo_width
        assign data_amo_write_data_o = {HPDcacheCfg.reqDataWidth/HPDcacheCfg.amoWidth{amo_write_data}};
        assign data_amo_write_user_o = {HPDcacheCfg.reqDataWidth/HPDcacheCfg.amoWidth{amo_write_user}};
    end else begin : gen_amo_ram_write_data_lt_amo_width
        assign data_amo_write_data_o = amo_write_data;
        assign data_amo_write_user_o = amo_write_user;
    end
//  }}}

//  Core response outputs
//  {{{
    assign req_ready_o      = (uc_fsm_q ==     UC_IDLE),
           core_rsp_valid_o = (uc_fsm_q == UC_CORE_RSP);
//  }}}

//  Memory read request outputs
//  {{{
    always_comb
    begin : mem_req_read_comb
        mem_req_read_o.mem_req_addr      = req_addr_q;
        mem_req_read_o.mem_req_len       = multiflit ? 1 : 0;
        mem_req_read_o.mem_req_size      = multiflit ? hpdcache_req_size_t'(3) : req_size_q;
        mem_req_read_o.mem_req_id        = mem_read_id_i;
        mem_req_read_o.mem_req_cacheable = 1'b0;
        mem_req_read_o.mem_req_command   = HPDCACHE_MEM_READ;
        mem_req_read_o.mem_req_atomic    = HPDCACHE_MEM_ATOMIC_ADD;

        unique case (1'b1)
            req_op_q.is_ld: begin
                mem_req_read_valid_o           = (uc_fsm_q == UC_MEM_REQ);
            end
            req_op_q.is_amo_lr: begin
                mem_req_read_o.mem_req_command = HPDCACHE_MEM_ATOMIC;
                mem_req_read_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_LDEX;
                mem_req_read_valid_o           = (uc_fsm_q == UC_MEM_REQ);
            end
            default: begin
                mem_req_read_valid_o           = 1'b0;
            end
        endcase
    end
//  }}}

//  Memory write request outputs
//  {{{
    always_comb
    begin : mem_req_write_comb
        mem_req_write_data                = req_data_q;
        mem_req_write_user                = req_user_q;
        mem_req_write_o.mem_req_addr      = req_addr_q;
        mem_req_write_o.mem_req_len       = multiflit ? 1 : 0;
        mem_req_write_o.mem_req_size      = multiflit ? hpdcache_req_size_t'(3) : req_size_q;
        mem_req_write_o.mem_req_id        = mem_write_id_i;
        mem_req_write_o.mem_req_cacheable = 1'b0;
        unique case (1'b1)
            req_op_q.is_amo_sc: begin
                mem_req_write_o.mem_req_command = HPDCACHE_MEM_ATOMIC;
                mem_req_write_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_STEX;
            end
            req_op_q.is_amo_swap: begin
                mem_req_write_o.mem_req_command = HPDCACHE_MEM_ATOMIC;
                mem_req_write_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_SWAP;
            end
            req_op_q.is_amo_add: begin
                mem_req_write_o.mem_req_command = HPDCACHE_MEM_ATOMIC;
                mem_req_write_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_ADD;
            end
            req_op_q.is_amo_and: begin
                mem_req_write_data              = ~mem_req_write_data;
                mem_req_write_o.mem_req_command = HPDCACHE_MEM_ATOMIC;
                mem_req_write_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_CLR;
            end
            req_op_q.is_amo_or: begin
                mem_req_write_o.mem_req_command = HPDCACHE_MEM_ATOMIC;
                mem_req_write_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_SET;
            end
            req_op_q.is_amo_xor: begin
                mem_req_write_o.mem_req_command = HPDCACHE_MEM_ATOMIC;
                mem_req_write_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_EOR;
            end
            req_op_q.is_amo_max: begin
                mem_req_write_o.mem_req_command = HPDCACHE_MEM_ATOMIC;
                mem_req_write_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_SMAX;
            end
            req_op_q.is_amo_maxu: begin
                mem_req_write_o.mem_req_command = HPDCACHE_MEM_ATOMIC;
                mem_req_write_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_UMAX;
            end
            req_op_q.is_amo_min: begin
                mem_req_write_o.mem_req_command = HPDCACHE_MEM_ATOMIC;
                mem_req_write_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_SMIN;
            end
            req_op_q.is_amo_minu: begin
                mem_req_write_o.mem_req_command = HPDCACHE_MEM_ATOMIC;
                mem_req_write_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_UMIN;
            end
            default: begin
                mem_req_write_o.mem_req_command = HPDCACHE_MEM_WRITE;
                mem_req_write_o.mem_req_atomic  = HPDCACHE_MEM_ATOMIC_ADD;
            end
        endcase

        unique case (uc_fsm_q)
            UC_MEM_REQ: begin
                unique case (1'b1)
                    req_op_q.is_st,
                    req_op_q.is_amo_sc,
                    req_op_q.is_amo_swap,
                    req_op_q.is_amo_add,
                    req_op_q.is_amo_and,
                    req_op_q.is_amo_or,
                    req_op_q.is_amo_xor,
                    req_op_q.is_amo_max,
                    req_op_q.is_amo_maxu,
                    req_op_q.is_amo_min,
                    req_op_q.is_amo_minu: begin
                        mem_req_write_data_valid_o = 1'b1;
                        mem_req_write_valid_o      = 1'b1;
                    end

                    default: begin
                        mem_req_write_data_valid_o = 1'b0;
                        mem_req_write_valid_o      = 1'b0;
                    end
                endcase
            end

            UC_MEM_W_REQ: begin
                mem_req_write_valid_o      = 1'b1;
                mem_req_write_data_valid_o = 1'b0;
            end

            UC_MEM_WDATA_REQ: begin
                mem_req_write_valid_o      = 1'b0;
                mem_req_write_data_valid_o = 1'b1;
            end

            UC_MEM_WDATA2_REQ: begin
                mem_req_write_valid_o      = 1'b0;
                mem_req_write_data_valid_o = 1'b1;
            end

            UC_MEM_W_AND_WDATA2_REQ: begin
                mem_req_write_valid_o      = 1'b1;
                mem_req_write_data_valid_o = 1'b1;
            end

            default: begin
                mem_req_write_valid_o      = 1'b0;
                mem_req_write_data_valid_o = 1'b0;
            end
        endcase
    end

    //  memory data width is bigger than the width of the core's interface
    if (HPDcacheCfg.u.capAmoEn) begin : gen_mem_req_write_data_capAmoEn
        // Currently only support REQ=128, MEM=64
        if (REQ_MEM_RATIO == 2) begin : gen_downsize_mem_req_data
            hpdcache_req_addr_t flit_addr;
            assign flit_addr = req_addr_q + (uc_fsm_q inside {UC_MEM_WDATA2_REQ, UC_MEM_W_AND_WDATA2_REQ} ? 'h8 : 'h0);
            assign mem_req_write_data_o.mem_req_w_data = mem_req_write_data >> (flit_addr[$clog2(HPDcacheCfg.u.memDataWidth/8) +: REQ_MEM_WORD_INDEX_WIDTH] * HPDcacheCfg.u.memDataWidth);
            assign mem_req_write_data_o.mem_req_w_be   = req_be_q >> (flit_addr[$clog2(HPDcacheCfg.u.memDataWidth/8) +: REQ_MEM_WORD_INDEX_WIDTH] * (HPDcacheCfg.u.memDataWidth/8));
            assign mem_req_write_data_o.mem_req_w_user = mem_req_write_user;
        end
    end else begin : gen_mem_req_write_data_default
        // Currently only support MEM >= REQ
        if (MEM_REQ_RATIO > 1) begin : gen_upsize_mem_req_data
            //  replicate data
            assign mem_req_write_data_o.mem_req_w_data = {MEM_REQ_RATIO{mem_req_write_data}};
            assign mem_req_write_data_o.mem_req_w_user = mem_req_write_user;

            //  demultiplex the byte-enable
            hpdcache_demux #(
                .NOUTPUT     (MEM_REQ_RATIO),
                .DATA_WIDTH  (HPDcacheCfg.reqDataWidth/8)
            ) mem_write_be_demux_i (
                .data_i      (req_be_q),
                .sel_i       (req_addr_q[$clog2(HPDcacheCfg.reqDataWidth/8) +:
                                         MEM_REQ_WORD_INDEX_WIDTH]),
                .data_o      (mem_req_write_data_o.mem_req_w_be)
            );
        end
        //  memory data width is equal to the width of the core's interface
        else if (MEM_REQ_RATIO == 1) begin : gen_eqsize_mem_req_data
            assign mem_req_write_data_o.mem_req_w_data = mem_req_write_data;
            assign mem_req_write_data_o.mem_req_w_be   = req_be_q;
            assign mem_req_write_data_o.mem_req_w_user = mem_req_write_user;
        end
    end

    assign mem_req_write_data_o.mem_req_w_last = !multiflit || uc_fsm_q inside {UC_MEM_WDATA2_REQ, UC_MEM_W_AND_WDATA2_REQ};
//  }}}

//  Response handling
//  {{{
    logic [HPDcacheCfg.amoWidth-1:0] sc_retcode;
    logic [HPDcacheCfg.amoWidth-1:0] sc_rdata_dword;
    hpdcache_req_data_t sc_rdata;

    assign sc_retcode = {{HPDcacheCfg.amoWidth-1{1'b0}}, uc_sc_retcode_q};
    assign sc_rdata_dword = prepare_amo_data_result(sc_retcode, req_size_q);
    if (HPDcacheCfg.reqDataWidth >= HPDcacheCfg.amoWidth) begin : gen_sc_rdata_ge_amo_width
        assign sc_rdata = {HPDcacheCfg.reqDataWidth/HPDcacheCfg.amoWidth{sc_rdata_dword}};
    end else begin : gen_sc_rdata_lt_amo_width
        assign sc_rdata = sc_rdata_dword;
    end

    assign core_rsp_o.rdata   = req_op_q.is_amo_sc ? sc_rdata : rsp_rdata_q;
    assign core_rsp_o.ruser   = req_op_q.is_amo_sc ? 1'b0 : rsp_ruser_q;
    assign core_rsp_o.sid     = req_sid_q;
    assign core_rsp_o.tid     = req_tid_q;
    assign core_rsp_o.error   = rsp_error_q;
    assign core_rsp_o.aborted = 1'b0;

    if (HPDcacheCfg.u.capAmoEn) begin : gen_rsp_rdata_capAmoEn
        // Currently only support REQ=128, MEM=64
        if (REQ_MEM_RATIO == 2) begin : gen_upsize_core_rsp_data
            assign rsp_rdata_d = (multiflit && mem_resp_read_i.mem_resp_r_last) ? {mem_resp_read_i.mem_resp_r_data, rsp_rdata_q[0][63:0] /* XXX fixme */} : {2{mem_resp_read_i.mem_resp_r_data}};
            assign rsp_ruser_d = (multiflit && mem_resp_read_i.mem_resp_r_last) ? {rsp_ruser_q && mem_resp_read_i.mem_resp_r_user} : mem_resp_read_i.mem_resp_r_user;
        end
    end else begin : gen_rsp_rdata_default
        //  Currently only support MEM >= REQ
        //  Resize the memory response data to the core response width
        //  memory data width is bigger than the width of the core's interface
        if (MEM_REQ_RATIO > 1) begin : gen_downsize_core_rsp_data
            hpdcache_mux #(
                .NINPUT      (MEM_REQ_RATIO),
                .DATA_WIDTH  (HPDcacheCfg.reqDataWidth)
            ) data_read_rsp_mux_i(
                .data_i      (mem_resp_read_i.mem_resp_r_data),
                .sel_i       (req_addr_q[$clog2(HPDcacheCfg.reqDataWidth/8) +:
                                         MEM_REQ_WORD_INDEX_WIDTH]),
                .data_o      (rsp_rdata_d)
            );

            if (HPDcacheCfg.u.userEn) begin : gen_rsp_ruser_userEn
                hpdcache_mux #(
                    .NINPUT      (MEM_REQ_RATIO),
                    .DATA_WIDTH  (HPDcacheCfg.reqWords * HPDcacheCfg.reqWordUserWidth)
                ) user_read_rsp_mux_i(
                    .data_i      (mem_resp_read_i.mem_resp_r_user),
                    .sel_i       (req_addr_q[$clog2(HPDcacheCfg.reqDataWidth/8) +:
                                             MEM_REQ_WORD_INDEX_WIDTH]),
                    .data_o      (rsp_ruser_d)
                );
            end else begin : gen_rsp_ruser_default
                assign rsp_ruser_d = '0;
            end
        end
        //  memory data width is equal to the width of the core's interface
        else if (MEM_REQ_RATIO == 1) begin : gen_eqsize_core_rsp_data
            assign rsp_rdata_d = mem_resp_read_i.mem_resp_r_data;
            assign rsp_ruser_d = HPDcacheCfg.u.userEn ? mem_resp_read_i.mem_resp_r_user : '0;
        end
    end

    //  This FSM is always ready to accept the response
    assign mem_resp_read_ready_o  = 1'b1,
           mem_resp_write_ready_o = 1'b1;
//  }}}

//  Set cache request registers
//  {{{
    always_ff @(posedge clk_i)
    begin : req_data_ff
        if (req_valid_i && req_ready_o) begin
            req_data_q <= req_data_i;
            req_user_q <= req_user_i;
            req_be_q <= req_be_i;
            req_sid_q <= req_sid_i;
            req_tid_q <= req_tid_i;
        end
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : req_ctrl_ff
        if (!rst_ni) begin
            req_op_q <= '0;
            req_addr_q <= '0;
            req_size_q <= '0;
            req_uc_q <= 1'b0;
            req_need_rsp_q <= req_need_rsp_i;
        end else if (req_valid_i && req_ready_o) begin
            req_op_q <= req_op_i;
            req_addr_q <= req_addr_i;
            req_size_q <= req_size_i;
            req_uc_q <= req_uc_i;
            req_need_rsp_q <= req_need_rsp_i;
        end
    end
//  }}}

//  Uncacheable request FSM set state
//  {{{
    logic lrsc_rsrv_valid_set, lrsc_rsrv_valid_reset;

    assign lrsc_rsrv_valid_set   = lrsc_uc_set,
           lrsc_rsrv_valid_reset = lrsc_uc_reset | lrsc_snoop_reset;

    always_ff @(posedge clk_i or negedge rst_ni)
    begin : uc_fsm_ff
        if (!rst_ni) begin
            uc_fsm_q          <= UC_IDLE;
            lrsc_rsrv_valid_q <= 1'b0;
        end else begin
            uc_fsm_q          <= uc_fsm_d;
            lrsc_rsrv_valid_q <= (~lrsc_rsrv_valid_q &  lrsc_rsrv_valid_set  ) |
                                 ( lrsc_rsrv_valid_q & ~lrsc_rsrv_valid_reset);
        end
    end

    always_ff @(posedge clk_i)
    begin : uc_amo_ff
        lrsc_rsrv_addr_q <= lrsc_rsrv_addr_d;
        uc_sc_retcode_q  <= uc_sc_retcode_d;
    end
//  }}}

//  Response registers
//  {{{
    always_ff @(posedge clk_i)
    begin
        if (mem_resp_read_valid_i) begin
            rsp_rdata_q <= rsp_rdata_d;
            rsp_ruser_q <= rsp_ruser_d;
        end
        mem_resp_write_valid_q <= mem_resp_write_valid_d;
        mem_resp_read_valid_q  <= mem_resp_read_valid_d;
    end

    always_ff @(posedge clk_i or negedge rst_ni)
    begin
        if (!rst_ni) begin
            rsp_error_q <= 1'b0;
        end else begin
            rsp_error_q <= (~rsp_error_q &  rsp_error_set) |
                           ( rsp_error_q & ~rsp_error_rst);
        end
    end
//  }}}

//  Assertions
//  {{{
`ifndef HPDCACHE_ASSERT_OFF
    assert property (@(posedge clk_i) disable iff (rst_ni !== 1'b1)
            (req_valid_i && req_op_i.is_ld) -> req_uc_i) else
                    $error("uc_handler: unexpected load request on cacheable region");

    assert property (@(posedge clk_i) disable iff (rst_ni !== 1'b1)
            (req_valid_i && req_op_i.is_st) -> req_uc_i) else
                    $error("uc_handler: unexpected store request on cacheable region");

    assert property (@(posedge clk_i) disable iff (rst_ni !== 1'b1)
            (req_valid_i && (req_op_i.is_amo_lr   ||
                             req_op_i.is_amo_sc   ||
                             req_op_i.is_amo_swap ||
                             req_op_i.is_amo_add  ||
                             req_op_i.is_amo_and  ||
                             req_op_i.is_amo_or   ||
                             req_op_i.is_amo_xor  ||
                             req_op_i.is_amo_max  ||
                             req_op_i.is_amo_maxu ||
                             req_op_i.is_amo_min  ||
                             req_op_i.is_amo_minu )) -> req_need_rsp_i) else
                    $error("uc_handler: amo requests shall need a response");

    assert property (@(posedge clk_i) disable iff (rst_ni !== 1'b1)
            (req_valid_i && (req_op_i.is_amo_lr   ||
                             req_op_i.is_amo_sc   ||
                             req_op_i.is_amo_swap ||
                             req_op_i.is_amo_add  ||
                             req_op_i.is_amo_and  ||
                             req_op_i.is_amo_or   ||
                             req_op_i.is_amo_xor  ||
                             req_op_i.is_amo_max  ||
                             req_op_i.is_amo_maxu ||
                             req_op_i.is_amo_min  ||
                             req_op_i.is_amo_minu )) -> (req_size_i inside {0,1,2,3,4})) else
                    $error("uc_handler: amo requests shall be at most 16 bytes wide");

    assert property (@(posedge clk_i) disable iff (rst_ni !== 1)
            (HPDcacheCfg.u.userEn -> HPDcacheCfg.reqDataWidth == 128)) else
                    $error("uc_handler: user_bits only handled as tags on 128-bit access width");

    assert property (@(posedge clk_i) disable iff (rst_ni !== 1)
            ((HPDcacheCfg.reqDataWidth == 128) -> $bits(hpdcache_req_user_t) == 1)) else
                    $error("uc_handler: must have exactly one tag bit with 128-bit access width");

    assert property (@(posedge clk_i) disable iff (rst_ni !== 1)
            (mem_resp_write_valid_i || mem_resp_read_valid_i) -> (uc_fsm_q == UC_MEM_WAIT_RSP)) else
                    $error("uc_handler: unexpected response from memory");
`endif
//  }}}

endmodule
