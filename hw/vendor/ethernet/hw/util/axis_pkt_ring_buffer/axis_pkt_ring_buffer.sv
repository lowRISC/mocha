// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

/*
Module: axis_pkt_ring_buffer
Author: Thomas O'Dea <thomas.odea@lowrisc.org>

-------------------------------------------------------------------------------
    DESCRIPTION
-------------------------------------------------------------------------------
Receives an AXI stream of data and stores it in a ring buffer, with a separate
table storing pointers and metadata about each packet. Packets are delimeted by
the 'tlast' signal.

Instantiates its own internal RAM for the buffer, and a random-access FIFO for
the descriptor table.

Once pkt_tvalid_i is asserted, we will begin capturing data in the ring buffer.
Whenever pkt_tlast_i is asserted, a new entry is added to the descriptor table
UNLESS pkt_abandon_i was asserted at any time during the packet, in which case
the packet is abandoned and will not be committed. Any data that was written
during that packet's streaming will be overwritten by the next packet.

When a packet is captured, the descriptor table stores:
    - a pointer to its start in the ring buffer
    - its length
    - the contents of pkt_metadata_i at the time of the packet's completion

There are two memory interfaces:
    - for reading the data buffer
    - for reading the descriptor table
Memory interfaces behave according to mem_if_utils_pkg.

The descriptor table can be read in any order, but entries can only be popped
(freed) from the head of the queue ("random-access FIFO"). Any entry in the
data buffer can be read at any time, but the data is only valid subject to the
descriptor table's pointers and lengths.

DrawIO instance template:
%3CmxGraphModel%3E%3Croot%3E%3CmxCell%20id%3D%220%22%2F%3E%3CmxCell%20id%3D%221%22%20parent%3D%220%22%2F%3E%3CmxCell%20id%3D%222%22%20value%3D%22%22%20style%3D%22group%22%20vertex%3D%221%22%20connectable%3D%220%22%20parent%3D%221%22%3E%3CmxGeometry%20x%3D%22240%22%20y%3D%22240%22%20width%3D%22600%22%20height%3D%22440%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%223%22%20value%3D%22AXIS%20PKT%20RING%20BUFFER%22%20style%3D%22rounded%3D0%3BwhiteSpace%3Dwrap%3Bhtml%3D1%3BfontFamily%3DCourier%20New%3BverticalAlign%3Dtop%3BfontStyle%3D1%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20width%3D%22600%22%20height%3D%22440%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%224%22%20value%3D%22pkt_tdata_i%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20y%3D%220.5%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%225%22%20value%3D%22pkt_tvalid_i%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20y%3D%2230.5%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%226%22%20value%3D%22pkt_tlast_i%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20y%3D%2261%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%227%22%20value%3D%22%26lt%3Bdiv%26gt%3B%26lt%3Bspan%20style%3D%26quot%3Bbackground-color%3A%20transparent%3B%20color%3A%20light-dark(rgb(0%2C%200%2C%200)%2C%20rgb(255%2C%20255%2C%20255))%3B%26quot%3B%26gt%3Bpkt_metadata_i%26lt%3B%2Fspan%26gt%3B%26lt%3B%2Fdiv%26gt%3B%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20y%3D%2291%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%228%22%20value%3D%22pkt_abandon_i%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20y%3D%22121.5%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%229%22%20value%3D%22table_req_i%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22540%22%20y%3D%2230.5%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2210%22%20value%3D%22table_addr_i%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22540%22%20y%3D%2260.5%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2211%22%20value%3D%22table_gnt_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22540%22%20y%3D%2290.5%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2212%22%20value%3D%22table_err_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22540%22%20y%3D%22120.5%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2213%22%20value%3D%22table_ptr_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22540%22%20y%3D%22150.5%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2214%22%20value%3D%22pkt_err_table_full_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20y%3D%22170%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2215%22%20value%3D%22pkt_err_buf_full_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20y%3D%22200%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2216%22%20value%3D%22table_pop_i%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22540%22%20y%3D%220.5%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2217%22%20value%3D%22table_metadata_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22540%22%20y%3D%22180.5%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2218%22%20value%3D%22buf_req_i%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22540%22%20y%3D%22260%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2219%22%20value%3D%22buf_addr_i%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22540%22%20y%3D%22290%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2220%22%20value%3D%22buf_gnt_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22540%22%20y%3D%22320%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2221%22%20value%3D%22buf_data_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22540%22%20y%3D%22350%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2222%22%20value%3D%22buf_full_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20y%3D%22320%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2223%22%20value%3D%22buf_almost_full_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20y%3D%22350%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2224%22%20value%3D%22table_full_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20y%3D%22380%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2225%22%20value%3D%22table_almost_full_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20y%3D%22410%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2226%22%20value%3D%22empty_o%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20y%3D%22290%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2227%22%20value%3D%22%22%20style%3D%22shape%3DcurlyBracket%3BwhiteSpace%3Dwrap%3Bhtml%3D1%3Brounded%3D1%3BlabelPosition%3Dleft%3BverticalLabelPosition%3Dmiddle%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BfontFamily%3DCourier%20New%3BfontSize%3D12%3BfontColor%3Ddefault%3BfillColor%3Dnone%3BgradientColor%3Dnone%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22450%22%20y%3D%2210%22%20width%3D%2220%22%20height%3D%22190%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2228%22%20value%3D%22%22%20style%3D%22shape%3DcurlyBracket%3BwhiteSpace%3Dwrap%3Bhtml%3D1%3Brounded%3D1%3BlabelPosition%3Dleft%3BverticalLabelPosition%3Dmiddle%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BfontFamily%3DCourier%20New%3BfontSize%3D12%3BfontColor%3Ddefault%3BfillColor%3Dnone%3BgradientColor%3Dnone%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22450%22%20y%3D%22270%22%20width%3D%2220%22%20height%3D%22100%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2229%22%20value%3D%22%22%20style%3D%22shape%3DcurlyBracket%3BwhiteSpace%3Dwrap%3Bhtml%3D1%3Brounded%3D1%3BflipH%3D1%3BlabelPosition%3Dright%3BverticalLabelPosition%3Dmiddle%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BfontFamily%3DCourier%20New%3BfontSize%3D12%3BfontColor%3Ddefault%3BfillColor%3Dnone%3BgradientColor%3Dnone%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22165%22%20y%3D%2210%22%20width%3D%2220%22%20height%3D%22210%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2230%22%20value%3D%22%22%20style%3D%22shape%3DcurlyBracket%3BwhiteSpace%3Dwrap%3Bhtml%3D1%3Brounded%3D1%3BflipH%3D1%3BlabelPosition%3Dright%3BverticalLabelPosition%3Dmiddle%3Balign%3Dleft%3BverticalAlign%3Dmiddle%3BfontFamily%3DCourier%20New%3BfontSize%3D12%3BfontColor%3Ddefault%3BfillColor%3Dnone%3BgradientColor%3Dnone%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22165%22%20y%3D%22290%22%20width%3D%2220%22%20height%3D%22140%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2231%22%20value%3D%22%22%20style%3D%22shape%3Dcylinder3%3BwhiteSpace%3Dwrap%3Bhtml%3D1%3BboundedLbl%3D1%3BbackgroundOutline%3D1%3Bsize%3D15%3Brounded%3D0%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BfontFamily%3DCourier%20New%3BfontSize%3D12%3BfontColor%3Ddefault%3BfillColor%3Dnone%3BgradientColor%3Dnone%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22260%22%20y%3D%22190%22%20width%3D%2260%22%20height%3D%2280%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2232%22%20value%3D%22%22%20style%3D%22shape%3Dcylinder3%3BwhiteSpace%3Dwrap%3Bhtml%3D1%3BboundedLbl%3D1%3BbackgroundOutline%3D1%3Bsize%3D15%3Brounded%3D0%3Balign%3Dright%3BverticalAlign%3Dmiddle%3BfontFamily%3DCourier%20New%3BfontSize%3D12%3BfontColor%3Ddefault%3BfillColor%3Dnone%3BgradientColor%3Dnone%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22330%22%20y%3D%22190%22%20width%3D%2260%22%20height%3D%2280%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2233%22%20value%3D%22Incoming%20packet%20interface%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dcenter%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3BfontSize%3D12%3BfontColor%3Ddefault%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22185%22%20y%3D%22100%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2234%22%20value%3D%22Table%20Memory%20Interface%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dcenter%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3BfontSize%3D12%3BfontColor%3Ddefault%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22390%22%20y%3D%2291.5%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2235%22%20value%3D%22Buffer%20Memory%20Interface%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dcenter%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3BfontSize%3D12%3BfontColor%3Ddefault%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22390%22%20y%3D%22305%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3CmxCell%20id%3D%2236%22%20value%3D%22Status%20Signals%22%20style%3D%22text%3Bhtml%3D1%3Balign%3Dcenter%3BverticalAlign%3Dmiddle%3BwhiteSpace%3Dwrap%3Brounded%3D0%3BfontFamily%3DCourier%20New%3BfontSize%3D12%3BfontColor%3Ddefault%3B%22%20vertex%3D%221%22%20parent%3D%222%22%3E%3CmxGeometry%20x%3D%22190%22%20y%3D%22345%22%20width%3D%2260%22%20height%3D%2230%22%20as%3D%22geometry%22%2F%3E%3C%2FmxCell%3E%3C%2Froot%3E%3C%2FmxGraphModel%3E

-------------------------------------------------------------------------------
    TESTS
-------------------------------------------------------------------------------
A dedicated testbench exists for this module which comapres its behaviour with
a Python model. See README.md for more details.

-------------------------------------------------------------------------------
    INSTANTIATION TEMPLATE
-------------------------------------------------------------------------------
// Ring buffer + descriptor table for capturing an AXI-Stream of packets
// Has its own internal memories which are accessible via two memory interfaces
axis_pkt_ring_buffer #(
    .PACKET_INDEX_W             (),     // allow 2^PACKET_INDEX_W packets in the buffer
    .BUF_ADDR_W                 (),     // allow 2^BUF_ADDR_W bytes in the buffer
    .MAX_PKT_LEN                (),     // maximum size of one packet
    .BufAlmostFullThreshold     (),     // recommended value is the maximum size of one packet, as above
    .TableAlmostFullThreshold   (),     // number of free entries in the descriptor table before we assert table_almost_full_o
    .metadata_t                 ()      // type for the metadata associated with each packet
) ring_buffer_inst (
    .clk_i,
    .rst_ni,

    // Packet input stream
    .pkt_tdata_i            (),
    .pkt_tvalid_i           (),
    .pkt_tlast_i            (),

    .pkt_metadata_i         (),
    .pkt_abandon_i          (),

    // Descriptor table access
    .table_req_i            (),
    .table_index_i          (),
    .table_gnt_o            (),
    .table_err_o            (),
    .table_metadata_o       (),
    .table_ptr_o            (),
    .table_pkt_len_o        (),

    .table_pop_i            (),

    // Data buffer access
    .buf_req_i              (),
    .buf_addr_i             (),
    .buf_err_o              (),
    .buf_data_o             (),
    .buf_gnt_o              (),

    // Statuses
    .empty_o                (),
    .packet_lost_o          (),
    .buf_almost_full_o      (),
    .table_full_o           (),
    .table_almost_full_o    (),
    .n_pkts_buffered_o      ()
);
*/

`include "prim_assert.sv"

module axis_pkt_ring_buffer #(
    parameter  PACKET_INDEX_W           = 3,  // constraints maximum number of buffered packets to 2^n
    parameter  BUF_ADDR_W               = 13, // width of the byte addresses for the buffer (constrains the maximum size of the buffer to 2^n bytes)
    parameter  MAX_PKT_LEN              = 1522, // maximum length of a packet in bytes

    parameter  BufAlmostFullThreshold   = 1524, // how many free entries in the buffer before we assert buf_almost_full_o?
    parameter  TableAlmostFullThreshold = 2, // how many free entries in the descriptor table before we assert table_almost_full_o?
    parameter  type metadata_t          = logic,

    localparam OUT_DATA_W               = 64, // width of the data bus for reading out the buffer (must be a multiple of IN_DATA_W)
    localparam PACKET_LEN_W             = $clog2(MAX_PKT_LEN), // width of the packet length field in the descriptor table (constrains the maximum packet length to 2^n bytes)
    localparam IN_DATA_W                = 8, // only support one byte as input for now
    localparam BUF_ADDR_LSBS            = $clog2(OUT_DATA_W/IN_DATA_W), // the number of least significant bits in the buffer address which are not used in the read address because we are reading out more bits at a time than we are writing in (i.e. we are upsizing)
    localparam type pkt_data_t          = logic [IN_DATA_W-1:0],
    localparam type bus_data_t          = logic [OUT_DATA_W-1:0],
    localparam type buffer_addr_t       = logic [BUF_ADDR_W-1:0],
    localparam type table_addr_t        = logic [PACKET_INDEX_W-1:0],
    localparam type pkt_len_t           = logic [PACKET_LEN_W-1:0]
) (
    input  logic                        clk_i,
    input  logic                        rst_ni,

    // Interface for capturing incoming packets and metadata
    input  pkt_data_t                   pkt_tdata_i,        // Incoming data (AXI-Stream)
    input  logic                        pkt_tlast_i,        // Indicates the end of a packet. Metadata will be captured and a new entry added to the descriptor table, UNLESS pkt_abandon_i was asserted any time during this packet (but not on the same cycle as tlast).
    input  logic                        pkt_tvalid_i,       // indicate whether any of the above signals are valid

    input  metadata_t                   pkt_metadata_i,     // Captured when a packet is committed
    input  logic                        pkt_abandon_i,      // When asserted, the current packet is abandoned and will not be commited. Valid when pkt_tvalid_i is asserted.

    // Interface for accessing the descriptor table (metadata + pointers to the buffer)
    input  logic                        table_pop_i,        // When asserted, entry 0 is popped (regardless of the value of table_req_i!)

    input  logic                        table_req_i,
    input  table_addr_t                 table_index_i,      // addresses are relative -- use 0 for the oldest packet, 1 for second oldest, etc.. Normal behaviour is to always read 0, but you can peek ahead if you like
    output logic                        table_gnt_o,
    output logic                        table_err_o,        // valid AFTER table_gnt_o is asserted. Indicates attempt to read bad entry in the descriptor table
    output metadata_t                   table_metadata_o,   // metadata read from the table (valid AFTER table_gnt_o)
    output buffer_addr_t                table_ptr_o,        // pointer to the packet being read fro mthe table (valid  table_gnt_o)
    output pkt_len_t                    table_pkt_len_o,    // length of the packet in bytes (valid after table_gnt_o)

    // Interface for accessing the buffer itself
    input  logic                        buf_req_i,
    input  buffer_addr_t                buf_addr_i,
    output logic                        buf_gnt_o,
    output bus_data_t                   buf_data_o,         // valid on the cycle FOLLOWING buf_gnt_o && buf_req_i
    output logic                        buf_err_o,          // valid on the cycle FOLLOWING buf_gnt_o && buf_req_i

    // Status/warning for the FIFOs
    output logic                        empty_o,
    output logic                        table_almost_full_o,
    output logic                        table_full_o,
    output logic                        buf_almost_full_o,
    output logic                        packet_lost_o,      // pulse for one cycle when a packet is lost (either due to full buffer or full table)
    output logic [PACKET_INDEX_W+1-1:0] n_pkts_buffered_o   // number of packets currently buffered in the descriptor table
);
    //////////////////
    // Declarations //
    //////////////////

    // Declare pointers
    buffer_addr_t buf_write_ptr;                // points to the next location to write incoming data to
    buffer_addr_t current_packet_head_ptr;      // points to the start of the current packet being captured (updated at the start of each new packet)

    // Signals used in logic for abandoning packets
    logic abandon_this_packet,abandon_sticky;   // flag which is set when pkt_abandon_i is asserted and ignores the current packet

    logic buf_full;                             // buffer full
    logic [BUF_ADDR_W-1:0] buffer_ptrs_margin;  // the number of words IN BETWEEN (exclusive) the read and write pointers on the buffer

    logic buf_write;    // write signal to the ring buffer
    logic commit_pkt;   // asserted at the end of a packet to commit it to the descriptor table
    logic abandon_pkt;  // asserted at the end of a packet to abandon it and not commit it to the descriptor table

    // Create the descriptor table and type
    typedef struct packed {
        logic [PACKET_LEN_W-1:0] pkt_len; // length of the packet in BYTES (not words!)
        metadata_t metadata;
        buffer_addr_t head_ptr;
    } pkt_desc_t;

    // Packet descriptions for the current packet, oldest packet, and randomly-read packet descriptor
    pkt_desc_t current_pkt_desc, oldest_packet_desc, oldest_packet_desc_raw, random_access_packet_desc;

    //////////////////////////
    // Packet abandon logic //
    //////////////////////////

    // The logic for abandoning packets is trickier than you might expect and took me a while to get right
    // so please read carefully if you are debugging or modifying this code
    // There are basically three reasons to abandon a packet:
    // 1. The buffer was full at any point during the packet (while tvalid was asserted)
    // 2. The external abandon signal was asserted at any point during the packet (while tvalid was asserted)
    // 3. The descriptor table was full AT THE COMPLETION of this packet (it's okay if it was full at the start)
    // and you need to make sure you handle the edge cases correctly

    // abandon_this_packet indicates that any of the three conditions for abandoning the packet are met
    // abandon_this_packet is only valid with tvalid and tlast
    assign abandon_this_packet = (
        abandon_sticky  || // sticky behaviour - if already true, stay true until the packet ends
        pkt_abandon_i   || // external instruction to abandon the packet (bypassing the flop in case its asserted on the very last cycle)
        buf_full        || // buffer full when the packet ends (as above)
        table_full_o       // description table full when the packet ends (it's okay if it's full when the packet starts, there could be a pop in the middle of the packet)
    );

    assign packet_lost_o = ((buf_full && pkt_tvalid_i) || (table_full_o && pkt_tlast_i && pkt_tvalid_i)) && ~abandon_sticky;
    // if the buffer was full at any point, if the table is full at the end of the packet, that packet will be lost
    // This will PULSE FOR ONE CYCLE when the packet is lost i.e. losing a packet is an event

    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni)                            abandon_sticky <= 1'b0;
        else if (pkt_tlast_i && pkt_tvalid_i)   abandon_sticky <= 1'b0;                     // reset after a packet ends
        else                                    abandon_sticky <= (pkt_abandon_i && pkt_tvalid_i) || packet_lost_o || abandon_sticky; // set and stay set if pkt_abandon_i is asserted and valid
    end

    /////////////////////////
    // Write pointer logic //
    /////////////////////////

    // Logic to check if the buffer is full
    assign buf_full                     = !empty_o && (oldest_packet_desc.head_ptr == buf_write_ptr);
    // if this goes high we should expect it to stay high for a while, because the write pointer will stop advancing once the buffer is full

    // Calculate remaining space in the buffer, excluding packet currently being written
    // we exclude the current packet to avoid th buf_almost_full flag being asserted and then deasserted partway through if the packet gets dropped
    assign buffer_ptrs_margin           = (empty_o ? current_packet_head_ptr : oldest_packet_desc.head_ptr) - current_packet_head_ptr; // the number of words IN BETWEEN (exclusive) the read and write pointers on the buffer
    assign buf_almost_full_o            = !empty_o && (buffer_ptrs_margin <= BUF_ADDR_W'(BufAlmostFullThreshold));

    assign buf_write = pkt_tvalid_i && ~buf_full && ~abandon_this_packet;
    // we should write incoming data to the buffer whenever it is valid, UNLESS we have decided to abandon this packet, or the buffer is full

    assign commit_pkt   = pkt_tvalid_i && pkt_tlast_i && ~abandon_this_packet;
    assign abandon_pkt  = pkt_tvalid_i && pkt_tlast_i &&  abandon_this_packet;

    // This simple module will advance the write pointer whenever valid_i is asserted
    // and also track the head of the current packet. If 'abandon' is asserted, the write
    // pointer moves back to the head of the packet. If 'commit' is asserted, the head
    // of the current packet is updated to where the write pointer is. See inside
    // for more details.
    axis_pkt_ring_buffer_wr_ptr_logic #(
        .PTR_W(BUF_ADDR_W)
    ) buf_wr_ptr_logic (
        .clk_i,
        .rst_ni,
        .valid_i        (buf_write || abandon_pkt), // only increment the pointer when we are actually WRITING to the buffer (or if we are abandoning the packet, we need valid_i asserted to reset the pointer)
        .commit_i       (commit_pkt),
        .abandon_i      (abandon_pkt),
        .wr_ptr_o       (buf_write_ptr),
        .head_ptr_o     (current_packet_head_ptr)
    );

    //////////////////////////////////
    // Declare the descriptor table //
    //////////////////////////////////
    // Create a table of packet descriptors (metadata + pointer) with random read access and popping mechanism
    // The contents of the descriptor table FIFO are not reset by anything
    // This is a major hazard for verification
    // To ensure no bugs, we should never use the data output of the FIFO while it is empty
    // To enforce this, we will MUX is it with an X which should propagate everywhere in simulation
    assign oldest_packet_desc = empty_o ? 'x : oldest_packet_desc_raw;


    // The descriptor table is a random-access FIFO
    // i.e. it has a "push" mechanism for writing to incrementing addressed
    //      and a "pop" mechanism for freeing up the oldest entry (like a conventional FIFO)
    //      but there is a second read interface which is addressable and allows arbitrary reads
    //      Read addresses are relative to the head of the queue, and attempting to read beyond the number of valid entries will result in an error
    random_access_fifo #(
        .dtype_t(pkt_desc_t),
        .AlmostFullThreshold(TableAlmostFullThreshold),
        .Depth(2**PACKET_INDEX_W)
    ) description_table (
        .clk_i,
        .rst_ni,
        .clr_i(1'b0), // not used

        // Write IF for pushing new packets onto queue
        .wr_push_i(commit_pkt),
        .wr_data_i(current_pkt_desc), // should capture the incoming metadata, and pointer to start of packet

        // Read IF for popping packets off the queue
        .rd_pop_i(table_pop_i),
        .rd_head_data_o(oldest_packet_desc_raw), // should return the metadata, and pointer for the oldest packet in the queue

        // Random-access read interface
        .rd_req_i(table_req_i),
        .rd_gnt_o(table_gnt_o),
        .rd_addr_i(table_index_i),
        .rd_data_o(random_access_packet_desc),
        .rd_err_o(table_err_o),

        // FIFO status
        .full_o(table_full_o),
        .almost_full_o(table_almost_full_o),
        .n_buffered_o(n_pkts_buffered_o), // number of packets currently buffered in the descriptor table
        .empty_o(empty_o)
    );
    logic unused;
    assign unused = ^{oldest_packet_desc.metadata,oldest_packet_desc.pkt_len}; // we only need the head_ptr of the oldest packet but the FIFO exposes all of it. Assigning to 'unused' waives lint warnings

    assign current_pkt_desc.metadata = pkt_metadata_i; // incoming metadata (only valid on tlast)
    assign current_pkt_desc.head_ptr = current_packet_head_ptr;
    assign current_pkt_desc.pkt_len = pkt_len_t'(buf_write_ptr + 1'b1 - current_packet_head_ptr); // this relies on unsigned overflow to work correctly

    // random access read interface:
    assign table_metadata_o = random_access_packet_desc.metadata;
    assign table_ptr_o = random_access_packet_desc.head_ptr;
    assign table_pkt_len_o = random_access_packet_desc.pkt_len;

    ////////////////////////////
    // Create the ring buffer //
    ////////////////////////////
    ram_upsizer_w8_r64 #(
        .RD_ADDR_W  (BUF_ADDR_W-BUF_ADDR_LSBS) // the read address is narrower because we are reading out more bits at a time than we are writing in (i.e. we are upsizing)
    ) ram_upsizer_w8_r64_inst (
        .clk_i,
        .rst_ni,

        // Write interface
        .wr_en_i    (buf_write),
        .wr_addr_i  (buf_write_ptr),
        .wr_data_i  (pkt_tdata_i),

        // Read interface
        .rd_en_i    (buf_req_i),
        .rd_addr_i  (buf_addr_i[BUF_ADDR_W-1:BUF_ADDR_LSBS]), // trim the LSBs off the address for reading because the RAM is word addressed, not byte addressed
        .rd_data_o  (buf_data_o)
    );

    // Read logic
    assign buf_gnt_o = buf_req_i; // grant immediately (protocol expects data on the following cycle as below)
    always_ff @ (posedge clk_i or negedge rst_ni) begin
        if (!rst_ni) begin
            buf_err_o  <= 1'b0;
        end else
        if (buf_req_i) begin
            buf_err_o  <= buf_addr_i[BUF_ADDR_LSBS-1:0] != '0; // error for unaligned accesses
        end
    end

    ////////////////
    // Assertions //
    ////////////////
    // Assert all outputs are known
    `ASSERT_KNOWN(TableGntO_A,                  table_gnt_o);
    `ASSERT_KNOWN_IF(TableErrO_A,               table_err_o,        $past(table_req_i && table_gnt_o));
    `ASSERT_KNOWN_IF(TableMetadataO_A,          table_metadata_o,   $past(table_req_i && table_gnt_o));
    `ASSERT_KNOWN_IF(TablePtrO_A,               table_ptr_o,        $past(table_req_i && table_gnt_o));

    `ASSERT_KNOWN(BufGntO_A,                    buf_gnt_o);
    `ASSERT_KNOWN_IF(BufDataO_A,                buf_data_o,         $past(buf_req_i && buf_gnt_o));
    `ASSERT_KNOWN_IF(BufErrO_A,                 buf_err_o,          $past(buf_req_i && buf_gnt_o));

    `ASSERT_KNOWN(EmptyO_A,                     empty_o);
    `ASSERT_KNOWN(BufAlmostFullO_A,             buf_almost_full_o);
    `ASSERT_KNOWN(TableFullO_A,                 table_full_o);
    `ASSERT_KNOWN(TableAlmostFullO_A,           table_almost_full_o);
    `ASSERT_KNOWN(PacketLostO_A,                packet_lost_o);
    `ASSERT_KNOWN(NPktsBufferedO_A,             n_pkts_buffered_o);

    // Some basic assertions about behaviour
    // cannot be both empty and full/nearly full
    `ASSERT(NotEmptyAndTableFull_A,             ~(empty_o && table_full_o));
    `ASSERT(NotEmptyAndTableAlmostFull_A,       ~(empty_o && table_almost_full_o));
    `ASSERT(NotEmptyAndBufferAlmostFull_A,      ~(empty_o && buf_almost_full_o));

    // 'almost full' is a subset of 'full'
    `ASSERT(BufAlmostFullWhenFull_A,            buf_full        -> buf_almost_full_o);
    `ASSERT(TableAlmostFullWhenFull_A,          table_full_o    -> table_almost_full_o);

    // gnt given immediately on both interfaces
    `ASSERT(BufGntImmediately_A,                buf_req_i       -> buf_gnt_o);
    `ASSERT(TableGntImmediately_A,              table_req_i     -> table_gnt_o);

    `ASSERT(NPktsDecreaseWithoutPop_A,          !table_pop_i    |=> n_pkts_buffered_o >= $past(n_pkts_buffered_o)); // cannot decrease the number of packets buffered without popping an entry from the descriptor table
    `ASSERT(NPktsIncreaseWithoutLast_A,         !pkt_tlast_i    |=> n_pkts_buffered_o <= $past(n_pkts_buffered_o)); // cannot increase the number of packets buffered without finishing a packet

    // values during reset
    `ASSERT(EmptyDuringReset_A,                 !rst_ni |-> empty_o,                     clk_i, 0);
    `ASSERT(TableNotFullDuringReset_A,          !rst_ni |-> !table_full_o,               clk_i, 0);
    `ASSERT(TableNotAlmostFullDuringReset_A,    !rst_ni |-> !table_almost_full_o,        clk_i, 0);
    `ASSERT(BufNotAlmostFullDuringReset_A,      !rst_ni |-> !buf_almost_full_o,          clk_i, 0);
    `ASSERT(NPktsZeroDuringReset_A,             !rst_ni |-> n_pkts_buffered_o == '0,     clk_i, 0);
    `ASSERT(PacketLostNotDuringReset_A,         !rst_ni |-> !packet_lost_o,              clk_i, 0);

    // values immediately after reset
    `ASSERT(EmptyAfterReset_A,                  !rst_ni |=> empty_o,                     clk_i, 0);
    `ASSERT(TableNotFullAfterReset_A,           !rst_ni |=> !table_full_o,               clk_i, 0);
    `ASSERT(TableNotAlmostFullAfterReset_A,     !rst_ni |=> !table_almost_full_o,        clk_i, 0);
    `ASSERT(BufNotAlmostFullAfterReset_A,       !rst_ni |=> !buf_almost_full_o,          clk_i, 0);
    `ASSERT(NPktsZeroAfterReset_A,              !rst_ni |=> n_pkts_buffered_o == '0,     clk_i, 0);
    `ASSERT(PacketLostNotAfterReset_A,          !rst_ni |=> !packet_lost_o,              clk_i, 0);
    //                                          ^ means we have just left reset          ^clock ^ should be a reset condition which disables the assertion, but we want these assertions to hold regardless of the reset
endmodule
