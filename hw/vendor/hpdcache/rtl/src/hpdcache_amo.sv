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
 *  Description   : HPDcache AMO computing unit
 *  History       :
 */
module hpdcache_amo
import hpdcache_pkg::*;
    //  Parameters
    //  {{{
#(
    parameter int unsigned DATA_WIDTH = 64,
    parameter int unsigned ARITH_WIDTH = DATA_WIDTH,
    parameter type user_t = logic,
    parameter bit userEn = 1'b0
)
//  Ports
//  {{{
(
    input  logic [DATA_WIDTH-1:0] ld_data_i,
    input  user_t                 ld_user_i,
    input  logic [DATA_WIDTH-1:0] st_data_i,
    input  user_t                 st_user_i,
    input  hpdcache_uc_op_t       op_i,
    output logic [DATA_WIDTH-1:0] result_o,
    output user_t                 user_o
);
//  }}}

    logic signed [ARITH_WIDTH-1:0] ld_data_signed;
    logic signed [ARITH_WIDTH-1:0] st_data_signed;
    logic signed [ARITH_WIDTH-1:0] sum;
    logic        [ARITH_WIDTH-1:0] ld_data_unsigned;
    logic        [ARITH_WIDTH-1:0] st_data_unsigned;
    logic        [ARITH_WIDTH-1:0] arith_result;
    logic ugt, sgt;

    assign ld_data_signed = ld_data_i[ARITH_WIDTH-1:0],
           st_data_signed = st_data_i[ARITH_WIDTH-1:0],
           ld_data_unsigned = ld_data_i[ARITH_WIDTH-1:0],
           st_data_unsigned = st_data_i[ARITH_WIDTH-1:0];

    assign ugt = (ld_data_unsigned > st_data_unsigned),
           sgt = (ld_data_signed   > st_data_signed),
           sum =  ld_data_signed   + st_data_signed;

    always_comb
    begin : amo_compute_comb
        // Artitmetic ops
        unique case (1'b1)
            op_i.is_amo_add  : arith_result = sum;
            op_i.is_amo_and  : arith_result = ld_data_unsigned & st_data_unsigned;
            op_i.is_amo_or   : arith_result = ld_data_unsigned | st_data_unsigned;
            op_i.is_amo_xor  : arith_result = ld_data_unsigned ^ st_data_unsigned;
            op_i.is_amo_max  : arith_result = sgt ? ld_data_unsigned : st_data_unsigned;
            op_i.is_amo_maxu : arith_result = ugt ? ld_data_unsigned : st_data_unsigned;
            op_i.is_amo_min  : arith_result = sgt ? st_data_unsigned : ld_data_unsigned;
            op_i.is_amo_minu : arith_result = ugt ? st_data_unsigned : ld_data_unsigned;
            default          : arith_result = '0;
        endcase
        // Non-arithmetic ops
        unique case (1'b1)
            op_i.is_amo_lr : begin
                result_o = ld_data_i;
                user_o = userEn ? ld_user_i : '0;
            end
            op_i.is_amo_sc : begin
                result_o = st_data_i;
                user_o = userEn ? st_user_i : '0;
            end
            op_i.is_amo_swap : begin
                result_o = st_data_i;
                user_o = userEn ? st_user_i : '0;
            end
            default : begin
                result_o = {{DATA_WIDTH - ARITH_WIDTH{1'b0}}, arith_result};
                user_o = '0;
            end
        endcase
    end

//  Assertions
//  {{{
`ifndef HPDCACHE_ASSERT_OFF
    initial
    begin : initial_assertions
        assert (DATA_WIDTH >= ARITH_WIDTH) else
            $error( "hpdcache_amo: DATA_WIDTH (%0d) must be greater than or equal to ARITH_WIDTH (%0d)"
                  , DATA_WIDTH, ARITH_WIDTH );
    end
`endif
//  }}}

endmodule
