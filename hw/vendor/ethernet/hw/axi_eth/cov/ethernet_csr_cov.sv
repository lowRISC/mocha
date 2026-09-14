// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: ethernet_csr_cov
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Coverage collection for the CSR block. Intended to be bound to the CSR block
by a testbench. Collects coverage on all the configuration and status registers,
as well as:
- cross-coverage on pairs of modes
- cross-coverage on status and events

This module makes use of upward hierarchical references to the CSR block, so it
must be bound to it. This is a very useful, albeit unintuitive SystemVerilog
feature: if THIS module makes reference to 'ethernet_csr', and there is nothing
in THIS scope called 'ethernet_csr', it will look upward in the hierarchy for
an instance or object with that name, or (as in this case) a module with that
name.

*/

module ethernet_csr_cov;
`ifdef COVERAGE
    covergroup ethernet_csr_cg @(posedge ethernet_csr.clk_i);
        // TODO this covergroup is too large and should be split into multiple smaller ones

        ////////////////
        // Interrupts //
        ////////////////
        cp_intr_tx_done     : coverpoint ethernet_csr.interrupts[5]; // cover true or false
        cp_intr_manual      : coverpoint ethernet_csr.interrupts[6]; // cover true or false
        cp_intr_pkt_lost    : coverpoint ethernet_csr.interrupts[4]; // cover true or false

        //////////////////////
        // RX Configuration //
        //////////////////////
        cp_promiscuity  : coverpoint ethernet_csr.rx_config_o.promiscuous_mode; // cover true or false
        cp_loopback     : coverpoint ethernet_csr.mac_config_o.loopback; // cover true or false
        cp_mac_addr     : coverpoint ethernet_csr.rx_config_o.mac_addr {
            bins all_set = {48'hFFFFFFFFFFFF};
            bins all_clear = {48'h000000000000};
            bins random = default;
        }; // cover min, max, and random MAC addresses
        cp_pop          : coverpoint ethernet_csr.rx_pop_o; // cover true or false

        ///////////////
        // RX Status //
        ///////////////
        cp_table_full           : coverpoint ethernet_csr.rx_status_i.table_full; // cover true or false
        cp_table_almost_full    : coverpoint ethernet_csr.rx_status_i.table_almost_full; // cover true or false
        cp_buf_almost_full      : coverpoint ethernet_csr.rx_status_i.buf_almost_full; // cover true or false
        cp_rx_buf_empty         : coverpoint ethernet_csr.rx_status_i.empty; // cover true or false
        cp_pkt_lost             : coverpoint ethernet_csr.rx_status_i.pkt_lost_pulse; // cover true or false
        cp_n_packets            : coverpoint ethernet_csr.rx_status_i.n_packets_in_rx_buf {
            bins zero = {4'd0};
            bins random = {[4'd1:4'd7]};
            bins max = {4'd8};
        }; // cover min, max, and random number of packets in RX buffer

        //////////////////////
        // TX Configuration //
        //////////////////////
        cp_tx_packet_len : coverpoint ethernet_csr.tx_config_o.packet_len {
            bins zero = {11'd0}; // TODO we have a bit of a problem here because I've covered all these different packet lengths, but the coverage still gets tracked even if there is no TX going on. We should only consider packet lengths WHEN a TX is actually kicked, maybe by using a sample() function?
            bins illegal_low = {[11'd1:11'd55]};
            bins min = {11'd56};
            bins random_legal = {[11'd57:11'd1517]};
            bins max = {11'd1518};
            bins illegal_high = {[11'd1519:11'd2046]};
            bins sat = {11'd2047};
        }; // cover min, max, and random packet lengths
        cp_kick_tx      : coverpoint ethernet_csr.tx_kick_o; // cover true or false

        ///////////////
        // TX Status //
        ///////////////
        cp_tx_busy      : coverpoint ethernet_csr.tx_status_i.busy; // cover true or false
        cp_tx_done      : coverpoint ethernet_csr.tx_status_i.done_pulse; // cover true or false

        ////////////////
        // RX Crosses //
        ////////////////

        // Modes, pairwise crosses
        cp_popXcp_n_packets     : cross cp_pop, cp_n_packets; // cover all combinations of pop and number of packets in RX buffer
        cp_promiscuityXloopback : cross cp_promiscuity, cp_loopback; // cover all combinations of promiscuous and loopback mode
        cp_promiscuityXmac_addr : cross cp_promiscuity, cp_mac_addr; // cover all combinations of promiscuous mode and MAC address
        cp_loopbackXmac_addr    : cross cp_loopback, cp_mac_addr; // cover all combinations of loopback mode and MAC address

        // Status crossed with events
        cp_table_fullXpkt_lost   : cross cp_table_full, cp_pkt_lost; // cover all combinations of table full and packet lost
        cp_table_almost_fullXpkt_lost : cross cp_table_almost_full, cp_pkt_lost; // cover all combinations of table almost full and packet lost
        cp_buf_almost_fullXpkt_lost : cross cp_buf_almost_full, cp_pkt_lost; // cover all combinations of buffer almost full and packet lost

        ////////////////
        // TX Crosses //
        ////////////////
        cp_tx_busyXkick_tx : cross cp_tx_busy, cp_kick_tx; // cover all combinations of TX busy and kick TX
        cp_tx_doneXkick_tx : cross cp_tx_done, cp_kick_tx; // cover all combinations of TX done and kick TX (getting both simultaneously could be tricky!)
    endgroup
    // TODO cover reads/writes to every register

    ethernet_csr_cg ethernet_csr_cg_inst;
    initial ethernet_csr_cg_inst = new();
`endif
endmodule
