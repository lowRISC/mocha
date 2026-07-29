// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "boot/trap.h"
#include "hal/mocha.h"
#include "runtime/print.h"

/////////////////////////////////////////////////////////
/// XOR shift to provide pseudorandom data for testing //
/////////////////////////////////////////////////////////
uint64_t xorshift() {
    static uint64_t state = 0xDEADBEEFCAFEBABEUL;
    state ^= (state << 13);
    state ^= (state >> 17);
    state ^= (state <<  5);
    return state;
}

////////////////////
// Test utilities //
////////////////////
struct {
    uint16_t fails; // checks within a test
    uint16_t passes; // checks within a test
    char *test_name;
    bool tests_failed;
} ethernet_test_status;

void ethernet_test_init() {
    ethernet_test_status.fails = 0;
    ethernet_test_status.passes = 0;
    ethernet_test_status.test_name = "";
    ethernet_test_status.tests_failed = false;
}

void ethernet_report_test(bool expect_no_checks) {
    uart_t uart = mocha_system_uart();

    char prefix;
    if (ethernet_test_status.fails > 0) {
        prefix = '!';
        ethernet_test_status.tests_failed = true;
    } else if (ethernet_test_status.fails == 0 && ethernet_test_status.passes == 0) {
        if (expect_no_checks) {
            prefix = ' ';
        } else {
            prefix = '?';
            ethernet_test_status.tests_failed = true;
        }
    } else {
        prefix = ' ';
    }

    uprintf(uart, "[%c%c%c%c] Ethernet test %s ended. Passes: 0x%x, Fails: 0x%x\n",
        prefix, prefix, prefix, prefix,
        ethernet_test_status.test_name, ethernet_test_status.passes, ethernet_test_status.fails);
}

void ethernet_begin_test(char *test_name) {
    uart_t uart = mocha_system_uart();
    uprintf(uart, "------ Ethernet test %s started\n", test_name);

    ethernet_test_status.test_name = test_name;
    ethernet_test_status.fails = 0;
    ethernet_test_status.passes = 0;
}

void ethernet_expect_equal(uint64_t measured, uint64_t expected, char *measurement_name) {
    uart_t uart = mocha_system_uart();
    if (measured != expected) {
        uprintf(uart, "       Ethernet test %s. Expected %s = 0x%lx, got 0x%lx\n",
            ethernet_test_status.test_name,
            measurement_name,
            expected,
            measured);
        ethernet_test_status.fails++;
    } else {
        ethernet_test_status.passes++;
    }
}

// Print a prefix for a test message
void ethernet_test_info() {
    uart_t uart = mocha_system_uart();
    uprintf(uart, "       Ethernet test %s: ", ethernet_test_status.test_name);
}

///////////////////
// Register test //
///////////////////
void ethernet_reg_test(ethernet_t ethernet) {
    ethernet_begin_test("REGISTER TEST");
    uint64_t dummy_data;

    ethernet_init(ethernet, 0xDEADBEEFCAFEBABEUL, false, ethernet_intr_none);

    ////////////////////////////////////////////////////
    // Test interrupt state, mask, and test registers //
    ////////////////////////////////////////////////////
    ethernet_intr intr_measured;

    intr_measured = ethernet_intr_state_get(ethernet);
    ethernet_expect_equal(intr_measured, 0, "interrupt state after init");

    intr_measured = ethernet_intr_mask_get(ethernet);
    ethernet_expect_equal(intr_measured, 0, "interrupt mask after init");

    for (uint8_t i = 0; i < 5; i++) {
        dummy_data = xorshift() & 0x7F;
        /* NOLINTNEXTLINE(clang-analyzer-optin.core.EnumCastOutOfRange) */
        ethernet_intr_mask_set(ethernet, (ethernet_intr)dummy_data); // enable all interrupts
        intr_measured = ethernet_intr_mask_get(ethernet);
        ethernet_expect_equal(intr_measured, dummy_data, "interrupt mask after write");
    }
    ethernet_intr_mask_set(ethernet, 0); // disable all interrupts again

    ethernet_test_intr_fire(ethernet); // fire test interrupt
    intr_measured = ethernet_intr_state_get(ethernet);
    ethernet_expect_equal(intr_measured,ethernet_intr_manual_irq,"interrupt state after test interrupt");
    ethernet_test_intr_clear(ethernet);
    intr_measured = ethernet_intr_state_get(ethernet);
    ethernet_expect_equal(intr_measured,0,"interrupt state after test interrupt cleared");
    // TODO test tx_done interrupt too

    //////////////////////////
    // Test status register //
    //////////////////////////
    ethernet_status status_measured;
    status_measured = ethernet_status_get(ethernet);
    ethernet_expect_equal(status_measured.rx_not_empty,          0, "status.rx_not_empty");
    ethernet_expect_equal(status_measured.rx_table_almost_full,  0, "status.rx_table_almost_full");
    ethernet_expect_equal(status_measured.rx_table_full,         0, "status.rx_table_full");
    ethernet_expect_equal(status_measured.rx_buf_almost_full,    0, "status.rx_buf_almost_full");
    ethernet_expect_equal(status_measured.packet_lost,           0, "status.packet_lost");
    ethernet_expect_equal(status_measured.tx_busy,               0, "status.tx_busy");
    ethernet_expect_equal(status_measured.n_packets_in_rx_buf,   0, "status.n_packets_in_rx_buf");
    // TODO test status after receiving a packet too

    ////////////////
    // Test modes //
    ////////////////
    ethernet_expect_equal(ethernet_mode_get(ethernet),ethernet_ctrl_none,"eth mode at init");
    ethernet_mode_set(ethernet, true, false); // promiscuous = true, loopback = false
    ethernet_expect_equal(ethernet_mode_get(ethernet),ethernet_ctrl_promiscuous_mode,"eth mode promiscuous");
    ethernet_mode_set(ethernet, false, true); // promiscuous = false, loopback = true
    ethernet_expect_equal(ethernet_mode_get(ethernet),ethernet_ctrl_loopback,"eth mode loopback");
    ethernet_mode_set(ethernet, true, true); // promiscuous = true, loopback = true
    ethernet_expect_equal(ethernet_mode_get(ethernet),ethernet_ctrl_promiscuous_mode | ethernet_ctrl_loopback,"eth mode loopback & promiscuous");
    ethernet_mode_set(ethernet, false, false);

    ////////////////////////
    // Test MAC addresses //
    ////////////////////////
    for(uint8_t i = 0; i < 5; ++i) {
        dummy_data = xorshift() & 0xFFFFFFFFFFFF; // 48-bit MAC address
        ethernet_mac_address_set(ethernet, dummy_data);
        ethernet_expect_equal(
            ethernet_mac_address_get(ethernet),
            (dummy_data & 0xFFFFFFFFFFFF),
            "MAC address test"
        );
    }

    // TODO test packet_send, pop_packet, buffer_write, buffer_read, metadata_get, tx_is_busy, rx_packet_pending
    ethernet_report_test(false);
}


///////////////////
// Loopback test //
///////////////////
void ethernet_loopback_test(ethernet_t ethernet, uint16_t pkt_len_bytes) {
    ethernet_begin_test("LOOPBACK TEST");
    uint8_t pkt_len_words = (pkt_len_bytes+7)/8;

    uint64_t dummy_data [191];
    ethernet_status status_measured;
    ethernet_init(ethernet, 0xDEADBEEFCAFEBABEUL, true, ethernet_intr_none);

    // Populate the dummy data
    for(uint8_t i = 0; i < pkt_len_words; i++) {
        uint64_t word = xorshift();
        dummy_data[i] = word;
        //ethernet_test_info(); uprintf(mocha_system_uart(), "loopback: dummy_data[%x] = %lx\n",i,word);
    }
    //for(uint8_t i = 0; i < pkt_len_words; i++) dummy_data[i] = xorshift();

    ///////////////////////
    // Set loopback mode //
    ///////////////////////
    ethernet_mode_set(ethernet, true, true); // promiscuous, loopback on

    ///////////////////////////////////////////
    // Write the dummy data to the TX buffer //
    ///////////////////////////////////////////
    for(uint8_t i = 0; i < pkt_len_words; i++) {
        ethernet_tx_buffer_write64(ethernet,i,dummy_data[i]);
    }

    //////////////////////
    // Fire the packet! //
    //////////////////////
    ethernet_tx_packet_trigger(ethernet,pkt_len_bytes);

    ///////////////////////////
    // Wait for it to arrive //
    ///////////////////////////
    while(ethernet_tx_is_busy(ethernet)) {};
    while(!ethernet_rx_packet_pending(ethernet)) {};

    //////////////////////
    // Check the status //
    //////////////////////
    status_measured = ethernet_status_get(ethernet);
    ethernet_expect_equal(status_measured.rx_not_empty,          1, "loopback: status.rx_not_empty");
    ethernet_expect_equal(status_measured.rx_table_almost_full,  0, "loopback: status.rx_table_almost_full");
    ethernet_expect_equal(status_measured.rx_table_full,         0, "loopback: status.rx_table_full");
    ethernet_expect_equal(status_measured.rx_buf_almost_full,    0, "loopback: status.rx_buf_almost_full");
    ethernet_expect_equal(status_measured.packet_lost,           0, "loopback: status.packet_lost");
    ethernet_expect_equal(status_measured.tx_busy,               0, "loopback: status.tx_busy");
    ethernet_expect_equal(status_measured.n_packets_in_rx_buf,   1, "loopback: status.n_packets_in_rx_buf");

    ///////////////////////
    // Read the metadata //
    ///////////////////////
    ethernet_pkt_metadata_t metadata;
    metadata = ethernet_rx_buffer_metadata_get(ethernet,0); // 0 is the oldest packet in the buffer, always
    ethernet_expect_equal(metadata.reason,NON_MAC_MATCH,"loopback metadata capture reason");
    ethernet_expect_equal(metadata.pkt_len,pkt_len_bytes,"loopback metadata packet length");

    ///////////////////
    // Read the data //
    ///////////////////
    for (uint16_t byte_idx = 0; byte_idx < pkt_len_bytes; byte_idx++) {
        ethernet_expect_equal(
            ethernet_rx_buffer_read_byte(ethernet, metadata.pkt_ptr + byte_idx),
            (dummy_data[byte_idx/8] >> (8*(byte_idx%8))) & 0xFF,
            "loopback data mismatch"
        );
    }

    ////////////////////
    // Pop the packet //
    ////////////////////
    ethernet_rx_pop_packet(ethernet);

    //////////////////
    // Check status //
    //////////////////
    status_measured = ethernet_status_get(ethernet);
    ethernet_expect_equal(status_measured.rx_not_empty,          0, "loopback after pop: status.rx_not_empty");
    ethernet_expect_equal(status_measured.rx_table_almost_full,  0, "loopback after pop: status.rx_table_almost_full");
    ethernet_expect_equal(status_measured.rx_table_full,         0, "loopback after pop: status.rx_table_full");
    ethernet_expect_equal(status_measured.rx_buf_almost_full,    0, "loopback after pop: status.rx_buf_almost_full");
    ethernet_expect_equal(status_measured.packet_lost,           0, "loopback after pop: status.packet_lost");
    ethernet_expect_equal(status_measured.tx_busy,               0, "loopback after pop: status.tx_busy");
    ethernet_expect_equal(status_measured.n_packets_in_rx_buf,   0, "loopback after pop: status.n_packets_in_rx_buf");

    ethernet_report_test(false);
}


/////////////
// TX test //
/////////////
void ethernet_tx_test(ethernet_t ethernet) {
    ethernet_begin_test("TX TEST");
    uint8_t dummy_data[64];
    ethernet_init(ethernet, 0xDEADBEEFCAFEBABEUL, true, ethernet_intr_none);

    // Populate the dummy data
    for(uint8_t i = 0; i < 64; i++) {
        dummy_data[i] = i;
        //ethernet_test_info(); uprintf(mocha_system_uart(), "loopback: dummy_data[%x] = %x\n",i,dummy_data[i]);
    }

    ethernet_send_packet(ethernet, dummy_data, 64);
    ethernet_test_info(); uprintf(mocha_system_uart(), "Ethernet test sequence: sent 64 bytes\n");
    while(ethernet_tx_is_busy(ethernet)) {};
    ethernet_test_info(); uprintf(mocha_system_uart(), "Ethernet test sequence completed sending\n");

    ethernet_report_test(true);
}

///////////////
// MDIO Test //
///////////////

// Test the MDIO bit-banging interface by reading/writing some PHY registers
// The PHY on the Genesys2 is a Realtek RTL8211E-VL PHY
// Manuals are available online with the register map
void ethernet_mdio_test(ethernet_t ethernet) {
    ethernet_begin_test("MDIO TEST");

    uint8_t phy_addr = 0x01; // we have only one PHY which has default address 1 on the MDIO bus
    uint16_t register_data;

    // Read PHYID register (1 and 2)
    register_data = ethernet_mdio_read(ethernet, phy_addr, 0x2);
    ethernet_expect_equal(register_data, 0x1c, "PHYID1 register"); // magic number from the datasheet
    register_data = ethernet_mdio_read(ethernet, phy_addr, 0x3);
    ethernet_expect_equal(register_data, 0b1100100100010101, "PHYID2 register"); // magic number from the datasheet

    // Read address 1 - status register
    register_data = ethernet_mdio_read(ethernet, phy_addr, 0x1);
    ethernet_expect_equal(register_data, 0b0111100101001001, "PHY status register"); // see PHY datasheet for this magic number

    // Read address 0 - control register
    register_data = ethernet_mdio_read(ethernet, phy_addr, 0x0);
    ethernet_expect_equal(register_data, 0x1140, "PHY control register");

    // Write address 0 - control register
    ethernet_mdio_write(ethernet, phy_addr, 0x0, register_data | 0x4000);

    // Read again
    register_data = ethernet_mdio_read(ethernet, phy_addr, 0x0);
    ethernet_expect_equal(register_data & 0x4000, 0x4000, "PHY loopback enable");

    // Return to old state
    ethernet_mdio_write(ethernet, phy_addr, 0x0, register_data & ~0x4000);

    ethernet_report_test(false);
}

//////////////////////
// Main test runner //
//////////////////////
bool test_main(void) {
    ethernet_t ethernet = mocha_system_ethernet();
    uart_t     uart     = mocha_system_uart();

    ethernet_test_init();

    ////////////////////
    // Run test cases //
    ////////////////////
    ethernet_mdio_test(ethernet);
    ethernet_tx_test(ethernet);
    ethernet_reg_test(ethernet);
    ethernet_loopback_test(ethernet, 1518); // max packet length
    ethernet_loopback_test(ethernet, 60); // min packet length
    ethernet_loopback_test(ethernet, 255);
    ethernet_loopback_test(ethernet, 256);
    ethernet_loopback_test(ethernet, 257);

    ////////////////////////////////////////////////////////
    // Receive one packet and dump its contents over UART //
    ////////////////////////////////////////////////////////
    // Note: no checks are performed here, you must manually cross-check the UART output with a Wireshark capture of the packet sent
    ethernet_init(ethernet, 0xDEADBEEFCAFEBABEUL, true, ethernet_intr_none);
    uint8_t pkt_data[1518];
    ethernet_pkt_metadata_t metadata;
    while (!ethernet_rx_packet_pending(ethernet)) {};
    metadata = ethernet_read_and_pop_oldest_packet(ethernet, pkt_data);
    uprintf(uart, "Received packet of length %x with reason %x\n",metadata.pkt_len,metadata.reason);

    uint64_t word;
    word = 0;
    for (uint16_t byte_idx = 0; byte_idx < metadata.pkt_len; byte_idx++) {
        word |= ((uint64_t)pkt_data[byte_idx]) << ((byte_idx%8)*8);
        if (byte_idx%8 == 7 || byte_idx == metadata.pkt_len-1) {
            uprintf(uart, "pkt_data[%x] = %lx\n",byte_idx/8,word);
            word = 0;
        }
    }
    uprintf(uart, "\n\n");

    ////////////
    // Return //
    ////////////
    return (ethernet_test_status.tests_failed == 0);
}
