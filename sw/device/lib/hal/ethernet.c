// Copyright lowRISC contributors (COSMIC project).
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0

#include "hal/ethernet.h"
#include "hal/mmio.h"
#include <stdbool.h>
#include <stdint.h>

//////////////////////////
/// Interrupt behaviour //
//////////////////////////

// Retrieve the interrupt state register (unmasked)
// which has flags indicating things like outstanding packets or completed transmissions
ethernet_intr ethernet_intr_state_get(ethernet_t ethernet) {
    return VOLATILE_READ(ethernet->intr_state);
}

// Retrieve the interrupt mask register (non-volatile register)
ethernet_intr ethernet_intr_mask_get(ethernet_t ethernet) {
    return VOLATILE_READ(ethernet->intr_mask);
}

// Set the interrupt mask register
void ethernet_intr_mask_set(ethernet_t ethernet, ethernet_intr intr_mask) {
    VOLATILE_WRITE(ethernet->intr_mask, intr_mask);
}

// Fire a test interrupt
void ethernet_test_intr_fire(ethernet_t ethernet) {
    ethernet_intr_test wr_val = {.set_manual_irq = 1};
    VOLATILE_WRITE( ethernet->intr_test, wr_val );
}

//////////////////////
// Clear interrupts //
//////////////////////
// status-type interrupts cannot be cleared directly, you must service the underlying condition causing the status
// however event-type interrupts can be cleared as below
// failing to clear them will cause them to immediately re-fire, so you must clear them or mask them after servicing
// It is perfectly acceptable to leave the interrupt asserted if you are not interested in it and have masked it

// Clear a test interrupt
void ethernet_test_intr_clear(ethernet_t ethernet) {
    // write-one-to-clear the manual_irq bit in the interrupt state register (INTR_STATE)
    VOLATILE_WRITE(ethernet->intr_state, ethernet_intr_manual_irq);
}

// Clear a TX done interrupt
void ethernet_tx_done_intr_clear(ethernet_t ethernet) {
    // write-one-to-clear the interrupt state register (INTR_STATE)
    VOLATILE_WRITE(ethernet->intr_state, ethernet_intr_tx_done);
}

// Clear a packet lost interrupt
void ethernet_packet_lost_intr_clear(ethernet_t ethernet) {
    // write-one-to-clear the interrupt state register (INTR_STATE)
    VOLATILE_WRITE(ethernet->intr_state, ethernet_intr_packet_lost);
}

///////////////////////
// Status and config //
///////////////////////

// Retrieve an ethernet status struct
ethernet_status ethernet_status_get(ethernet_t ethernet) {
    return VOLATILE_READ(ethernet->status);
}

// Set the mode: promiscuous or not, loopback or not
// When in loopback mode, ONLY TX packets will arrive on the RX path, so other traffic will be lost
// Only use loopback for testing
void ethernet_mode_set(ethernet_t ethernet, bool promiscuous_en, bool loopback_en) {
    ethernet_ctrl config = ethernet_ctrl_none;
    if (promiscuous_en) {
        config = (ethernet_ctrl)(config | ethernet_ctrl_promiscuous_mode);
    }
    if (loopback_en) {
        config = (ethernet_ctrl)(config | ethernet_ctrl_loopback);
    }
    VOLATILE_WRITE(ethernet->ctrl , config);
}

// Retrieve the mode (non-volatile register)
ethernet_ctrl ethernet_mode_get(ethernet_t ethernet) {
    return VOLATILE_READ(ethernet->ctrl);
}

// Set the MAC address ('address' is 64-bit, but only 48 lower bits are used)
void ethernet_mac_address_set(ethernet_t ethernet, uint64_t address) {
    ethernet_machi machi = {.mac_hi = (address >> 32) & 0xffff};
    VOLATILE_WRITE( ethernet->maclo         , (uint32_t)(address & 0xffffffff));
    VOLATILE_WRITE( ethernet->machi         , machi);
}

// Retrieve the MAC address (non-volatile register)
uint64_t ethernet_mac_address_get(ethernet_t ethernet) {
    uint64_t maclo = VOLATILE_READ(ethernet->maclo);
    uint64_t machi = VOLATILE_READ(ethernet->machi).mac_hi;
    return (machi << 32) | maclo;
}

/////////////////////
// Buffer accesses //
/////////////////////

// Write a 64-bit word to the TX buffer at the given word offset
void ethernet_tx_buffer_write64(ethernet_t ethernet, uint32_t word_offset, uint64_t data) {
    VOLATILE_WRITE(ethernet->tx_data_buf[word_offset], data);
}

// Read a 64-bit word from the RX buffer at the given word offset
uint64_t ethernet_rx_buffer_read64(ethernet_t ethernet, uint32_t word_offset) {
    return VOLATILE_READ(ethernet->rx_data_buf[word_offset]);
}

// Read a single byte from the RX buffer at the given byte offset
static uint16_t last_word_offset_read = -1;
// word offset of the last word read from the RX buffer, used to cache the last word read to avoid redundant reads (the compiler won't optimise this for us because the RX buffer is volatile)
uint8_t ethernet_rx_buffer_read_byte(ethernet_t ethernet, uint16_t byte_offset) {
    // Reads one byte from the RX buffer.
    // Because the buffer has to be marked as volatile to avoid being cached, repeated byte reads will
    // not be optimised into a wide read. To avoid this, we can store one word in a static variable in RAM
    // But then we need to make sure we invalidate that cached word if the buffer could have changed
    // The buffer can't change until we pop the packet* so we invalidate on pop
    // *strictly speaking if we read outside of valid memory, the buffer could change without a pop, but why are you reading outside of valid memory?
    static uint64_t word = 0;

    if (last_word_offset_read != byte_offset / 8) {
        word = ethernet_rx_buffer_read64(ethernet, byte_offset / 8);
        last_word_offset_read = byte_offset / 8;
    }
    return (word >> ((byte_offset & 7)*8)) & 0xFF;
}

// Retrieve metadata for the nth oldest packet (index=0 being the oldest packet)
ethernet_pkt_metadata_t ethernet_rx_buffer_metadata_get(ethernet_t ethernet, uint8_t index) {
    if (index >= ETHERNET_RX_TABLE_DEPTH) {
        ethernet_pkt_metadata_t invalid = {0};
        return invalid;
    }
    uint64_t reg = VOLATILE_READ(ethernet->rx_desc_table[index]);
    ethernet_pkt_metadata_t metadata;
    metadata.reason    = (ethernet_capture_reason_e)((reg & ETHERNET_RXTABLE_REASON_MASK) >> ETHERNET_RXTABLE_REASON_OFFSET);
    metadata.pkt_ptr   = (reg & ETHERNET_RXTABLE_PKT_PTR_MASK) >> ETHERNET_RXTABLE_PKT_PTR_OFFSET;
    metadata.pkt_len   = (reg & ETHERNET_RXTABLE_PKT_LEN_MASK) >> ETHERNET_RXTABLE_PKT_LEN_OFFSET;
    return metadata;
}

// Copy a packet's data from the RX buffer into a provided buffer
// Does NOT free the packet
void ethernet_read_packet_data_raw(ethernet_t ethernet, uint16_t packet_start_ptr, uint16_t len, uint8_t *data) {
    // Copy the whole packet into the provided data buffer
    for (uint16_t i = 0; i < len; i++) {
        data[i] = ethernet_rx_buffer_read_byte(ethernet, packet_start_ptr + i);
    }
}

///////////////////
// TX/RX Control //
///////////////////

// Trigger a transmission of a packet of length len_bytes
uint8_t ethernet_tx_packet_trigger(ethernet_t ethernet, uint16_t len_bytes) {
    if ((len_bytes > 1518) || (len_bytes < 56)) { // 1518 is the max size without the CRC, 56 is the min size without the CRC
        return 1; // packet length is invalid
    }

    ethernet_tx_ctrl tx_ctrl = {.tx_packet_len = len_bytes};
    VOLATILE_WRITE(ethernet->tx_ctrl, tx_ctrl);
    // writing the length has the side effect of triggering the send

    return 0;
}

// Pop the oldest packet from the RX buffer, freeing up space for new packets
void ethernet_rx_pop_packet(ethernet_t ethernet) {
    last_word_offset_read = -1; // once a pop happens some data in the RX buffer COULD change, so we invalidate the cached word
    ethernet_rx_pop pop = {.pop = 1};
    VOLATILE_WRITE(ethernet->rx_pop, pop);
}

// Check if TX is busy
bool ethernet_tx_is_busy(ethernet_t ethernet) {
    return ethernet_status_get(ethernet).tx_busy;
}

// Check if RX has 1 or more packets buffered
bool ethernet_rx_packet_pending(ethernet_t ethernet) {
    return ethernet_status_get(ethernet).rx_not_empty;
}

//////////
// MDIO //
//////////

// For internal use
ethernet_mdio_ctrl ethernet_mdio_ctrl_raw_get(ethernet_t ethernet) {
    return VOLATILE_READ(ethernet->mdio_ctrl);
}

// For internal use
void ethernet_mdio_ctrl_raw_set(ethernet_t ethernet, ethernet_mdio_ctrl mdio_ctrl) {
    VOLATILE_WRITE(ethernet->mdio_ctrl, mdio_ctrl);
}

// Set MDIO direction (true = output, false = input)
void ethernet_mdio_dir_set(ethernet_t ethernet, bool mdio_out_en) {
    ethernet_mdio_ctrl mdio_ctrl = ethernet_mdio_ctrl_raw_get(ethernet);
    if (mdio_out_en) {
        mdio_ctrl |=  ethernet_mdio_ctrl_mdio_oen;
    } else {
        mdio_ctrl &= ~ethernet_mdio_ctrl_mdio_oen;
    }
    ethernet_mdio_ctrl_raw_set(ethernet, mdio_ctrl);
}

// Set output MDIO value
void ethernet_mdio_out_set(ethernet_t ethernet, bool mdio_out) {
    ethernet_mdio_ctrl mdio_ctrl = ethernet_mdio_ctrl_raw_get(ethernet);
    if (mdio_out) {
        mdio_ctrl |=  ethernet_mdio_ctrl_mdio_o;
    } else {
        mdio_ctrl &= ~ethernet_mdio_ctrl_mdio_o;
    }
    ethernet_mdio_ctrl_raw_set(ethernet, mdio_ctrl);
}

// Get input MDIO value
bool ethernet_mdio_in_get(ethernet_t ethernet) {
    ethernet_mdio_ctrl mdio_ctrl = ethernet_mdio_ctrl_raw_get(ethernet);
    return (mdio_ctrl & ethernet_mdio_ctrl_mdio_i) != 0;
}

// Set MDIO clock value
void ethernet_mdio_c_set(ethernet_t ethernet, bool mdio_clk) {
    ethernet_mdio_ctrl mdio_ctrl = ethernet_mdio_ctrl_raw_get(ethernet);
    if (mdio_clk) {
        mdio_ctrl |=  ethernet_mdio_ctrl_mdio_clk;
    } else {
        mdio_ctrl &= ~ethernet_mdio_ctrl_mdio_clk;
    }
    ethernet_mdio_ctrl_raw_set(ethernet, mdio_ctrl);
}

// Pulse the MDIO clock line high then low (with a small delay)
void ethernet_mdc_pulse(ethernet_t ethernet) {
    // The delays are probably unnecessary but included to be safe
    // system clock is 50 MHz = 8ns period and MDC has to be asserted for at least 160 ns = 20 clocks
    // I would be absolutely shocked if the bus turns around that fast but we'll add a little busywait to be sure

    for(volatile int i = 0; i < 10; i++) {}; // busy wait
    ethernet_mdio_c_set(ethernet, true);
    for(volatile int i = 0; i < 10; i++) {}; // busy wait
    ethernet_mdio_c_set(ethernet, false);
}

// Set MDIO output data t hen pulse clock line
void ethernet_mdio_write_bit(ethernet_t ethernet, bool bit) {
    ethernet_mdio_out_set(ethernet, bit);
    ethernet_mdc_pulse(ethernet);
}

// Pulse clock line then read MDIO data bit
bool ethernet_mdio_read_bit(ethernet_t ethernet) {
    ethernet_mdc_pulse(ethernet);
    return ethernet_mdio_in_get(ethernet);
}

////////////////////////
// High-level methods //
////////////////////////

// Initialise the ethernet
// Sets the MAC address, promiscuity, and interrupt mask
//
// This function ALMOST perfectly resets the internal state of the Ethernet hardware, with a few exceptions:
// - the location of the pointer in the RX write buffer will be retained, but this is not relevant as you should always read from the RX buffer using a pointer provided by the metadata table
// - any in-progress transmissions will not be interrupted and will complete
// - the data in the RX memory will not be wiped (but it will be marked as free so could be overwritten at any time by an incoming packet)
// - the data in the TX memory will not be wiped (but you can overwrite it any time you like)
//
// * intr_mask *
// A typical interrupt mask is (ethernet_intr_rx_not_empty)
// i.e. interrupt for all new packets or for manually triggered interrupts
// An alternative would be (ethernet_intr_rx_table_almost_full | ethernet_intr_rx_buf_almost_full)
// i.e. only interrupt when the table or buffer is almost full (i.e. >=6 packets are buffered, or there are fewer than 1522 bytes left in the buffer)
// this will generate fewer interrupts and you could have the ISR pop ALL packets when it fires
//
// * promiscuous *
// If promiscuous is true, the ethernet will accept all packets, regardless of destination MAC address
// If it is false, it will only accept packets destined for its MAC address, or broadcast/multicast packets
void ethernet_init(ethernet_t ethernet, uint64_t mac_address, bool promiscuous, ethernet_intr intr_mask) {
    // Write config registers
    ethernet_mode_set(ethernet, promiscuous, false); // set to promiscuous or non-promiscuous mode, but not loopback mode
    ethernet_mac_address_set(ethernet, mac_address);
    ethernet_intr_mask_set(ethernet,intr_mask);

    // Clear any outstanding interrupts
    ethernet_test_intr_clear(ethernet);
    ethernet_tx_done_intr_clear(ethernet);
    ethernet_packet_lost_intr_clear(ethernet);

    // Pop any packets left in the buffer
    while(ethernet_rx_packet_pending(ethernet)) {
        ethernet_rx_pop_packet(ethernet);
    }

    // Possible improvement would be to include a 'reset' CSR that forcefully clears the internal state of the Ethernet hardware
    // though as far as I know, clearing all interrupts and popping all packets is almost equivalent to that
}

// Reads the oldest packet from the RX buffer and copies its data (including 4 CRC bytes) into the provided buffer
// Also pops the packet from the RX buffer, freeing up space for new packets
// Returns the metadata for the packet, including its length (including the CRC)
ethernet_pkt_metadata_t ethernet_read_and_pop_oldest_packet(ethernet_t ethernet, uint8_t *data) {
    if (!ethernet_rx_packet_pending(ethernet)) {
        ethernet_pkt_metadata_t bad_pkt;
        bad_pkt.pkt_len = 0;
        bad_pkt.pkt_ptr = 0;
        return bad_pkt; // no packet to read
    }

    // Read the oldest packet in the RX buffer
    ethernet_pkt_metadata_t metadata = ethernet_rx_buffer_metadata_get(ethernet, 0);
    uint16_t packet_pointer = metadata.pkt_ptr;
    uint16_t packet_end = metadata.pkt_ptr + metadata.pkt_len; // end byte of the packet

    // Copy the whole packet into the provided data buffer
    while (packet_pointer < packet_end) {
        *data++ = ethernet_rx_buffer_read_byte(ethernet, packet_pointer++);
        // Remember, the RX buffer is volatile, so if we just 'memcpy' it will compile as a whole long series of individual
        // byte reads. As designers, we know that while the buffer is technically volatile, it cannot change until a pop occurs
        // so we can need to do some trickery here to read a whole word at a time, then break it into bytes once it's in non-volatile RAM
        // read_byte is clever: it caches the last word read to avoid redundant reads, and invalidates the cache on pop
        // so we should only have to read from the RX buffer once per word, even if we read one byte at a time here
        // the compiler should also be able to figure out that we are copying whole words here and leverage that, since the
        // only volatile part happens inside read_byte
    }

    // Free the packet from the hardware
    ethernet_rx_pop_packet(ethernet);

    // The data has been copied out to the provided buffer, but we will also return the metadata if the caller wants it
    // Importantly this includes the packet length
    return metadata;
}

// Copies packet data into the TX buffer then kicks off a transmission and returns immediately
// The data should include the source MAC, destination MAC, ethertype/length, and payload
// It should not include the preamble, SFD, CRC, or inter-frame gap - those are handled by the hardware
// Returns 0 if the packet was sent successfully, or a nonzero error code if it was not
uint8_t ethernet_send_packet(ethernet_t ethernet, const uint8_t *data, uint16_t len_bytes) {
    if (ethernet_tx_is_busy(ethernet)) {
        return 1; // TX is busy, can't send a packet right now
    }
    if (len_bytes > 1518) { // 1518 is the max size without the CRC
        return 2; // packet is too long, can't send it
    }
    if (len_bytes < 56) { // min size without the CRC
        return 3; // packet is too short, can't send it
    }

    uint8_t len_words = (len_bytes + 7) / 8; // round up to nearest word

    // Copy the whole packet into the TX buffer
    for (uint16_t i = 0; i < len_words; i++) {
        uint64_t word = 0;
        for (uint8_t j = 0; j < 8; j++) {
            word |= ((uint64_t)data[i*8 + j]) << (j*8);
            // Check endianness on this?
        }
        // The compiler should be able to optimise this -- we are going doing some bitwise algebra here
        // to get a 64-bit word, but its layout in memory is already exactly as we need it so no arithmetic
        // is needed if the compiler is clever
        ethernet_tx_buffer_write64(ethernet, i, word);
    }
    // Trigger the transmission
    ethernet_tx_packet_trigger(ethernet, len_bytes);

    // The call is responsible for attaching metadata: source MAC, destination MAC, ethertype/length, and the payload
    // The hardware will automatically add the preamble, SFD, CRC, and inter-frame gap

    return 0; // packet sending (though not necessarily done yet)
}

// Mask all interrupts and ignore incoming traffic
// outstanding interrupts won't be cleared
void ethernet_disable(ethernet_t ethernet) {
    ethernet_intr_mask_set(ethernet, ethernet_intr_none); // mask all interrupts
    ethernet_mode_set(ethernet, false, true); // disable promiscuous and enter loopback mode
    // in loopback we won't receive anything unless we TX it ourselves
}

// MDIO write PHY register
void ethernet_mdio_write(ethernet_t ethernet, uint8_t phy_addr, uint8_t reg_addr, uint16_t data) {
    // Set the MDIO direction to output
    ethernet_mdio_dir_set(ethernet, true);

    // Write the preamble - 32 continuous 1's
    for (uint8_t i = 0; i < 32; i++) {
        ethernet_mdio_write_bit(ethernet, true);
    }

    // Write the start of frame - 01
    ethernet_mdio_write_bit(ethernet, false);
    ethernet_mdio_write_bit(ethernet, true);

    // Write the opcode - 01 for write
    ethernet_mdio_write_bit(ethernet, false);
    ethernet_mdio_write_bit(ethernet, true);

    // Write the PHY address - 5 bits
    for (int8_t i = 4; i >= 0; i--) {
        ethernet_mdio_write_bit(ethernet, (phy_addr >> i) & 0x1);
    }

    // Write the register address - 5 bits
    for (int8_t i = 4; i >= 0; i--) {
        ethernet_mdio_write_bit(ethernet, (reg_addr >> i) & 0x1);
    }

    // Write the turnaround - 2 bits (10)
    ethernet_mdio_write_bit(ethernet, true);
    ethernet_mdio_write_bit(ethernet, false);

    // Write the data - 16 bits
    for (int8_t i = 15; i >= 0; i--) {
        ethernet_mdio_write_bit(ethernet, (data >> i) & 0x1);
    }

    // Release MDIO line
    ethernet_mdio_dir_set(ethernet, false);
}

// MDIO read PHY register
uint16_t ethernet_mdio_read(ethernet_t ethernet, uint8_t phy_addr, uint8_t reg_addr) {
    // Set the MDIO direction to output
    ethernet_mdio_dir_set(ethernet, true);

    // Write the preamble - 32 continuous 1's
    for (uint8_t i = 0; i < 32; i++) {
        ethernet_mdio_write_bit(ethernet, true);
    }

    // Write the start of frame - 01
    ethernet_mdio_write_bit(ethernet, false);
    ethernet_mdio_write_bit(ethernet, true);

    // Write the opcode - 10 for read
    ethernet_mdio_write_bit(ethernet, true);
    ethernet_mdio_write_bit(ethernet, false);

    // Write the PHY address - 5 bits
    for (int8_t i = 4; i >= 0; i--) {
        ethernet_mdio_write_bit(ethernet, (phy_addr >> i) & 0x1);
    }

    // Write the register address - 5 bits
    for (int8_t i = 4; i >= 0; i--) {
        ethernet_mdio_write_bit(ethernet, (reg_addr >> i) & 0x1);
    }

    // Turnaround - set MDIO to input and read two bits
    ethernet_mdio_dir_set(ethernet, false);
    //(void)ethernet_mdio_read_bit(ethernet); // Discard the first turnaround bit
    bool turnaround_bit_2 = ethernet_mdio_read_bit(ethernet);

    if (turnaround_bit_2 != false) {
        return -1; // Error: invalid turnaround bit
    }

    // Read the data - 16 bits
    uint16_t data = 0;
    for (int8_t i = 15; i >= 0; i--) {
        bool bit = ethernet_mdio_read_bit(ethernet);
        data |= (bit << i);
    }

    return data;
}
