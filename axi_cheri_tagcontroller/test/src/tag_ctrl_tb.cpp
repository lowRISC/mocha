// Licensed to the Apache Software Foundation (ASF) under one
// or more contributor license agreements.  See the NOTICE file
// distributed with this work for additional information
// regarding copyright ownership.  The ASF licenses this file
// to you under the Apache License, Version 2.0 (the
// "License"); you may not use this file except in compliance
// with the License.  You may obtain a copy of the License at

//   http://www.apache.org/licenses/LICENSE-2.0

// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

#include "Vtag_ctrl_testharness.h"
#include "Vtag_ctrl_testharness_tag_ctrl_testharness.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#ifdef COVERAGE
#include "verilated_cov.h"
#endif

#include <cstdlib>
#include <time.h>
#include <stdio.h>
#include <iostream>
#include <iomanip>
#include <string>
#include <getopt.h>
#include <chrono>
#include <ctime>
#include <signal.h>
#include <unistd.h>
#include <gtest/gtest.h>
#include <cmath>
#include <deque>
#include <axi_types.h>

#define MAX_NUM_REPS 1000

static vluint64_t main_time = 0;
static std::string dumpfolder = "/test/logs/";
static std::string dumpfile = "dump.vcd";
#ifdef COVERAGE
static std::string covfile = "coverage.dat";
#endif

/////////////
// helpers //
///////////////////////////////////////////////////////////////////////////////

static inline uint64_t get_cap_addr(uint64_t byte_addr) {
  static const int shift = (int)std::abs(std::log2(Vtag_ctrl_testharness_tag_ctrl_testharness::CapSize / 8));
  return byte_addr >> shift;
}

class CTagctrl_tb : public ::testing::Test
{
protected:
  Vtag_ctrl_testharness *top;
  VerilatedVcdC *tfp;
  VerilatedContext *contextp;

  void SetUp()
  {
    main_time = 0;
    contextp = new VerilatedContext;
    top = new Vtag_ctrl_testharness(contextp);
#if VM_TRACE
    // Enable Trace
    Verilated::traceEverOn(true); // Verilator must compute traced signals
    tfp = new VerilatedVcdC;
    top->trace(tfp, 99); // Trace 99 levels of hierarchy
    std::string test_name = ::testing::UnitTest::GetInstance()->current_test_info()->name();
    dumpfile = dumpfolder + test_name + "_dump.vcd";
    tfp->open(dumpfile.c_str());
#endif
    reset();
  }

  void TearDown()
  {
#ifdef COVERAGE
    std::string test_name = ::testing::UnitTest::GetInstance()->current_test_info()->name();
    covfile = dumpfolder + test_name + "_coverage.dat";
    Verilated::threadContextp()->coveragep()->write(covfile.c_str());
#endif
    delete top;
#if VM_TRACE
    tfp->close();
    delete tfp;
#endif
    delete contextp;
  }

public:
  void reset()
  {
    for (int i = 0; i < 10; i++)
    {
      top->rst_ni = 0;
      top->clk_i = 0;
      top->eval();
#if VM_TRACE
      tfp->dump(static_cast<vluint64_t>(main_time * 2));
#endif
      top->clk_i = 1;
      top->eval();
#if VM_TRACE
      tfp->dump(static_cast<vluint64_t>(main_time * 2 + 1));
#endif
      main_time++;
    }
    top->rst_ni = 1;
  }

  /**
   * @brief Function to tick the DUT.
   * @param N number of clock ticks to increment.
   * @returns void.
   */
  void tick(int N)
  {
    for (int i = 0; i < N; i++)
    {
      top->clk_i = 0;
      top->eval();
#if VM_TRACE
      tfp->dump(static_cast<vluint64_t>(main_time * 2));
#endif
      top->clk_i = 1;
      top->eval();
#if VM_TRACE
      tfp->dump(static_cast<vluint64_t>(main_time * 2 + 1));
#endif
      main_time++;
    }
  }
};

class CTagCtrlDriver_tb
{
private:
  Vtag_ctrl_testharness *dut;
  CTagctrl_tb *tb;

public:
  CTagCtrlDriver_tb(Vtag_ctrl_testharness *dut, CTagctrl_tb *tb)
  {
    this->dut = dut;
    this->tb = tb;
    //srand(time(0));
    srand(0);
  }

  void reset_slave()
  {
    dut->cpu_aw_addr = 0;
    dut->cpu_aw_valid = 0;
    dut->cpu_w_valid = 0;
    dut->cpu_w_data = 0;
    dut->cpu_w_strb = 0;
    dut->cpu_w_last = 0;
    dut->cpu_b_ready = 0;
    dut->cpu_ar_valid = 0;
    dut->cpu_ar_addr = 0;
    dut->cpu_r_ready = 0;
  }

  void send_aw(axi_ax_beat_t aw_beat)
  {
    dut->cpu_aw_id = aw_beat.ax_id;
    dut->cpu_aw_addr = aw_beat.ax_addr;
    dut->cpu_aw_len = aw_beat.ax_len;
    dut->cpu_aw_size = aw_beat.ax_size;
    dut->cpu_aw_burst = aw_beat.ax_burst;
    dut->cpu_aw_user = aw_beat.ax_user;
    dut->cpu_aw_valid = 1;
    if (dut->cpu_aw_ready == 1)
    {
      tb->tick(1);
    }
    else
    {
      while (dut->cpu_aw_ready != 1)
        tb->tick(1);
      tb->tick(1);
    }
    dut->cpu_aw_addr = 0;
    dut->cpu_aw_valid = 0;
    dut->cpu_aw_id = 0;
    dut->cpu_aw_addr = 0;
    dut->cpu_aw_len = 0;
    dut->cpu_aw_size = 0;
    dut->cpu_aw_burst = 0;
    dut->cpu_aw_user = 0;
    dut->cpu_aw_valid = 0;
  }

  void send_w(axi_w_beat_t w_beat)
  {
    dut->cpu_w_data = w_beat.w_data;
    dut->cpu_w_strb = w_beat.w_strb;
    dut->cpu_w_last = w_beat.w_last;
    dut->cpu_w_user = w_beat.w_user;
    dut->cpu_w_valid = 1;
    if (dut->cpu_w_ready == 1)
    {
      tb->tick(1);
    }
    else
    {
      while (dut->cpu_w_ready != 1)
        tb->tick(1);
      tb->tick(1);
    }
    dut->cpu_w_data = 0;
    dut->cpu_w_strb = 0;
    dut->cpu_w_last = 0;
    dut->cpu_w_user = 0;
    dut->cpu_w_valid = 0;
  }

  void send_ar(axi_ax_beat_t ar_beat)
  {
    dut->cpu_ar_id = ar_beat.ax_id;
    dut->cpu_ar_addr = ar_beat.ax_addr;
    dut->cpu_ar_len = ar_beat.ax_len;
    dut->cpu_ar_size = ar_beat.ax_size;
    dut->cpu_ar_burst = ar_beat.ax_burst;
    dut->cpu_ar_user = ar_beat.ax_user;
    dut->cpu_ar_valid = 1;
    if (dut->cpu_ar_ready == 1)
    {
      tb->tick(1);
    }
    else
    {
      while (dut->cpu_ar_ready != 1)
        tb->tick(1);
      tb->tick(1);
    }
    dut->cpu_ar_addr = 0;
    dut->cpu_ar_valid = 0;
    dut->cpu_ar_id = 0;
    dut->cpu_ar_addr = 0;
    dut->cpu_ar_len = 0;
    dut->cpu_ar_size = 0;
    dut->cpu_ar_burst = 0;
    dut->cpu_ar_user = 0;
    dut->cpu_ar_valid = 0;
  }

  axi_b_beat_t recv_b()
  {
    axi_b_beat_t b_beat{
      b_id : 0,
      b_resp : RESP_DECERR,
      b_user : 0,
      b_valid : 0
    };
    dut->cpu_b_ready = 1;
    while (dut->cpu_b_valid != 1)
      tb->tick(1);
    b_beat.b_id = dut->cpu_b_id;
    b_beat.b_resp = (axi_resp_t)dut->cpu_b_resp;
    b_beat.b_user = dut->cpu_b_user;
    b_beat.b_valid = 1;
    tb->tick(1);
    dut->cpu_b_ready = 0;
    return b_beat;
  }

  axi_r_beat_t recv_r()
  {
    axi_r_beat_t r_beat = {0, 0, RESP_DECERR, 0, 0, 0};
    dut->cpu_r_ready = 1;
    while (dut->cpu_r_valid != 1)
      tb->tick(1);
    r_beat.r_id = dut->cpu_r_id;
    r_beat.r_data = dut->cpu_r_data;
    r_beat.r_resp = static_cast<axi_resp_t>(dut->cpu_r_resp);
    r_beat.r_last = dut->cpu_r_last;
    r_beat.r_user = dut->cpu_r_user;
    r_beat.r_valid = 1;
    tb->tick(1);
    return r_beat;
  }

  void send_write(uint64_t addr,
                  uint64_t data, // upper 64 bit 0
                  uint8_t user = 0,
                  axi_resp_t expected_resp = RESP_OKAY)
  {
    dut->cpu_aw_id    = 0;
    dut->cpu_aw_addr  = addr;
    dut->cpu_aw_len   = 0;
    dut->cpu_aw_size  = 4;
    dut->cpu_aw_burst = BURST_INCR;
    dut->cpu_aw_user  = user;
    dut->cpu_aw_valid = 1;

    dut->eval();

    while (dut->cpu_aw_ready != 1)
      tb->tick(1);

    tb->tick(1);

    dut->cpu_aw_valid = 0;
    dut->cpu_aw_id    = 0;
    dut->cpu_aw_addr  = 0;
    dut->cpu_aw_len   = 0;
    dut->cpu_aw_size  = 0;
    dut->cpu_aw_burst = 0;
    dut->cpu_aw_user  = 0;


    dut->cpu_w_data = 0;
    dut->cpu_w_data = data;

    dut->cpu_w_strb = 0xffff;
    dut->cpu_w_last = 1;
    dut->cpu_w_user = user;
    dut->cpu_w_valid = 1;

    dut->eval();

    while (dut->cpu_w_ready != 1)
      tb->tick(1);

    tb->tick(1);

    dut->cpu_w_valid = 0;
    dut->cpu_w_data  = 0;
    dut->cpu_w_strb  = 0;
    dut->cpu_w_last  = 0;
    dut->cpu_w_user  = 0;

    dut->cpu_b_ready = 1;

    while (dut->cpu_b_valid != 1)
      tb->tick(1);

    EXPECT_EQ(dut->cpu_b_id, 0);
    EXPECT_EQ(static_cast<axi_resp_t>(dut->cpu_b_resp),
              expected_resp);

    tb->tick(1);

    dut->cpu_b_ready = 0;
  }


  std::tuple<uint64_t, uint8_t, axi_resp_t>
  send_read(uint64_t addr)
  {

    dut->cpu_ar_id    = 0;
    dut->cpu_ar_addr  = addr;
    dut->cpu_ar_len   = 0;
    dut->cpu_ar_size  = 4;
    dut->cpu_ar_burst = BURST_INCR;
    dut->cpu_ar_user  = 0;
    dut->cpu_ar_valid = 1;

    dut->eval();

    while (dut->cpu_ar_ready != 1)
      tb->tick(1);

    tb->tick(1);

    dut->cpu_ar_valid = 0;
    dut->cpu_ar_id    = 0;
    dut->cpu_ar_addr  = 0;
    dut->cpu_ar_len   = 0;
    dut->cpu_ar_size  = 0;
    dut->cpu_ar_burst = 0;
    dut->cpu_ar_user  = 0;

    dut->cpu_r_ready = 1;

    while (dut->cpu_r_valid != 1)
      tb->tick(1);

    uint64_t r_data = dut->cpu_r_data;
    uint8_t r_user = dut->cpu_r_user;
    axi_resp_t r_resp =
        static_cast<axi_resp_t>(dut->cpu_r_resp);

    EXPECT_EQ(dut->cpu_r_id, 0);
    EXPECT_EQ(dut->cpu_r_last, 1);

    tb->tick(1);

    dut->cpu_r_ready = 0;

    return {r_data, r_user, r_resp};
  }

  axi_ax_beat_t rand_ax_beat(uint64_t base, uint64_t length)
  {
    axi_ax_beat_t ax_beat;
    ax_beat.ax_id = rand() % (int)fabs((pow(2, Vtag_ctrl_testharness_tag_ctrl_testharness::AxiIdWidth)));

    ax_beat.ax_addr = (rand() % length) + base;
    ax_beat.ax_addr = ax_beat.ax_addr & ~static_cast<uint64_t>(0xfff);

    if (ax_beat.ax_addr < base) {
      ax_beat.ax_addr = (base + 4095) & ~static_cast<uint64_t>(0xfff);
    }

    ax_beat.ax_len = (uint8_t)(2); // Hardcoded 3 beats (len=2) matching your original test
    ax_beat.ax_size = 3; // Always 64-bit for now
    ax_beat.ax_burst = BURST_INCR;
    ax_beat.ax_user = 0;
    return ax_beat;
  }

  axi_w_beat_t rand_w_beat(int last, uint64_t base, uint64_t length)
  {
    axi_w_beat_t w_beat;
    w_beat.w_strb = 0xff;
    w_beat.w_data = (rand() % length) + base;
    w_beat.w_user = rand() % 2;
    w_beat.w_last = last;
    return w_beat;
  }

  void reset_cfg_slave()
  {
    dut->cfg_aw_addr = 0;
    dut->cfg_aw_valid = 0;
    dut->cfg_w_valid = 0;
    dut->cfg_w_data = 0;
    dut->cfg_w_strb = 0;
    dut->cfg_w_last = 0;
    dut->cfg_b_ready = 0;
    dut->cfg_ar_valid = 0;
    dut->cfg_ar_addr = 0;
    dut->cfg_r_ready = 0;
  }

  void send_cfg_write(uint32_t addr, uint64_t data)
  {
    dut->cfg_aw_addr = addr & 0xFFF;
    dut->cfg_aw_valid = 1;
    dut->cfg_w_data = data;
    dut->cfg_w_strb = 0xffffffffffffffffULL;
    dut->cfg_w_last = 1;
    dut->cfg_w_valid = 1;
    dut->eval();

    while (dut->cfg_aw_valid == 1 || dut->cfg_w_valid == 1)
    {
      bool aw_ready_sampled = (dut->cfg_aw_ready == 1);
      bool w_ready_sampled  = (dut->cfg_w_ready == 1);

      tb->tick(1);

      if (dut->cfg_aw_valid == 1 && aw_ready_sampled)
      {
        dut->cfg_aw_valid = 0;
      }
      if (dut->cfg_w_valid == 1 && w_ready_sampled)
      {
        dut->cfg_w_valid = 0;
      }
    }

    dut->cfg_aw_addr = 0;
    dut->cfg_w_data = 0;
    dut->cfg_w_strb = 0;
    dut->cfg_w_last = 0;

    dut->cfg_b_ready = 1;
    while (dut->cfg_b_valid != 1)
      tb->tick(1);
    tb->tick(1);
    dut->cfg_b_ready = 0;
  }

  uint64_t send_cfg_read(uint32_t addr)
  {
    uint64_t r_data = 0;

    dut->cfg_ar_addr = addr & 0xFFF;
    dut->cfg_ar_valid = 1;
    dut->eval();
    if (dut->cfg_ar_ready == 1)
    {
      tb->tick(1);
    }
    else
    {
      while (dut->cfg_ar_ready != 1) {
        tb->tick(1);
      }
      tb->tick(1);
    }
    dut->cfg_ar_addr = 0;
    dut->cfg_ar_valid = 0;

    dut->cfg_r_ready = 1;
    while (dut->cfg_r_valid != 1)
    {
      tb->tick(1);
    }
    r_data = dut->cfg_r_data;
    tb->tick(1);
    dut->cfg_r_ready = 0;

    return r_data;
  }

  bool wait_for_status_bit(uint8_t bit_index, bool expected_val = true, int max_polls = 100, int tick_interval = 10)
  {
    for (int timeout = 0; timeout < max_polls; timeout++) {
      uint64_t status = send_cfg_read(0x000);
      bool bit_state = (status >> bit_index) & 0x1;
      if (bit_state == expected_val) {
        return true;
      }
      tb->tick(tick_interval);
    }
    return false;
  }

  void wait_and_clear(vluint8_t& valid_sig, const vluint8_t& ready_sig) {
    valid_sig = 1;
    while (ready_sig != 1) {
      tb->tick(1);
    }
    tb->tick(1);
    valid_sig = 0;
  }

};

void run_rand_rw_sequence(
  CTagCtrlDriver_tb* driver,
  uint64_t base,
  uint64_t length,
  bool expect_user_tag = true,
  axi_resp_t expected_b_resp = RESP_OKAY,
  axi_resp_t expected_r_resp = RESP_OKAY,
  uint64_t num_reps = MAX_NUM_REPS)
{
  std::deque<axi_w_beat_t> axi_w_beat_q;

  for (uint64_t rep = 0; rep < num_reps; rep++) {
    axi_ax_beat_t aw_beat = driver->rand_ax_beat(base, length);
    axi_ax_beat_t ar_beat = aw_beat;

    driver->reset_slave();
    driver->send_aw(aw_beat);

    axi_w_beat_t last_w_beat;
    uint8_t len = aw_beat.ax_len;

    for (uint64_t i = 0; i <= len; i++) {
      bool last = (i == len);
      axi_w_beat_t w_beat = driver->rand_w_beat(last, base, length);

      uint64_t addr = get_cap_addr(aw_beat.ax_addr + i * 8);
      uint64_t last_addr = get_cap_addr(aw_beat.ax_addr + (i > 0 ? (i - 1) * 8 : 0));

      if (i > 0 && last_addr == addr) {
        w_beat.w_user = last_w_beat.w_user;
      }

      driver->send_w(w_beat);
      axi_w_beat_q.push_back(w_beat);
      last_w_beat = w_beat;
    }

    axi_b_beat_t b_beat = driver->recv_b();
    ASSERT_EQ(b_beat.b_id, aw_beat.ax_id);
    ASSERT_EQ(b_beat.b_resp, expected_b_resp);

    driver->send_ar(ar_beat);

    for (uint64_t i = 0; i <= len; i++) {
      axi_r_beat_t r_beat = driver->recv_r();
      axi_w_beat_t exp_w_beat = axi_w_beat_q.front();
      axi_w_beat_q.pop_front();

      ASSERT_EQ(r_beat.r_id, ar_beat.ax_id);
      if (expected_r_resp == RESP_OKAY) ASSERT_EQ(r_beat.r_data, exp_w_beat.w_data);
      ASSERT_EQ(r_beat.r_resp, expected_r_resp);
      ASSERT_EQ(r_beat.r_last, (i == len) ? 1 : 0);

      uint8_t expected_user = expect_user_tag ? exp_w_beat.w_user : 0;
      ASSERT_EQ(r_beat.r_user, expected_user);
    }
  }
}

///////////
// tests //
///////////////////////////////////////////////////////////////////////////////

TEST_F(CTagctrl_tb, Rand_AXI_RW_OP)
{
  CTagCtrlDriver_tb *driver = new CTagCtrlDriver_tb(top, this);
  tick(2500);

  // Pulling base and length configurations directly from the harness layout definitions
  uint64_t base = Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase;
  uint64_t length = Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemLength;

  // Correctly passing all required parameters to the sequence helper
  run_rand_rw_sequence(driver, base, length);

  delete driver;
}

TEST_F(CTagctrl_tb, Config_Interface_Full_Cycle)
{
  CTagCtrlDriver_tb *driver = new CTagCtrlDriver_tb(top, this);

  // Initialize and reset interfaces
  driver->reset_slave();
  driver->reset_cfg_slave();
  tick(20);

  // Assert initially in Zeroing state (Bit 1)
  uint64_t status = driver->send_cfg_read(0x000);
  bool zeroing = (status >> 1) & 0x1;
  ASSERT_TRUE(zeroing);

  // Wait until device progresses into Serving state (Bit 0)
  ASSERT_TRUE(driver->wait_for_status_bit(0 /* serving */))
    << "Timeout waiting for FSM to enter SERVING state during initial boot.";

  // Issue "stop" sequence command path via configuration register
  driver->send_cfg_write(0x008, 0x10000);
  tick(1);

  // Wait for design to reach Unconfigured state (Bit 3)
  ASSERT_TRUE(driver->wait_for_status_bit(3 /*unconfigured */))
    << "Timeout waiting for FSM to return to UNCONFIGURED state.";

  // Setup addressing layouts constraints
  uint64_t exp_base = 0x00004000; // Aligned with COVERED_ALIGN (8192)
  uint64_t exp_top  = 0x00008000; // Aligned with COVERED_ALIGN (8192)
  uint64_t exp_tbl  = 0x00000100; // Aligned with TAG_STORE_ALIGN (64)

  driver->send_cfg_write(0x010, exp_base);
  driver->send_cfg_write(0x018, exp_top);
  driver->send_cfg_write(0x020, exp_tbl);

  // Verify configurations were accurately captured
  ASSERT_EQ(driver->send_cfg_read(0x010), exp_base);
  ASSERT_EQ(driver->send_cfg_read(0x018), exp_top);
  ASSERT_EQ(driver->send_cfg_read(0x020), exp_tbl);

  // Verify no layout tracking errors are flagged (Bits 23:16)
  status = driver->send_cfg_read(0x000);
  uint8_t error_field = (status >> 16) & 0xFF;
  ASSERT_EQ(error_field, 0);

  // Trigger "start" command sequence path
  driver->send_cfg_write(0x008, 0x1);
  tick(1);

  // Wait until active cycle moves through Zeroing state and back into Serving
  ASSERT_TRUE(driver->wait_for_status_bit(1 /* zeroing */))
    << "Timeout waiting for FSM to enter ZEROING state.";

  ASSERT_TRUE(driver->wait_for_status_bit(0 /* serving */))
    << "Timeout waiting for FSM to enter SERVING state.";

  delete driver;
}

TEST_F(CTagctrl_tb, TagStore_Aliasing_Access)
{
  CTagCtrlDriver_tb *driver = new CTagCtrlDriver_tb(top, this);

  // Initialize and reset interfaces
  driver->reset_slave();
  driver->reset_cfg_slave();
  tick(20);

  // Wait until device progresses into Serving state (Bit 0)
  ASSERT_TRUE(driver->wait_for_status_bit(0 /* serving */))
    << "Timeout waiting for FSM to enter SERVING state during initial boot.";

  driver->send_cfg_write(0x008, 0x10000); // stop command
  tick(1);
  ASSERT_TRUE(driver->wait_for_status_bit(3 /* unconfigured */));

  uint64_t small_base  = 0x00004000;
  uint64_t small_top   = 0x00006000; // base + 8192 bytes
  uint64_t tag_tbl_ptr = 0x00001000; // Lower internal tag storage base pointer

  driver->send_cfg_write(0x010, small_base);
  driver->send_cfg_write(0x018, small_top);
  driver->send_cfg_write(0x020, tag_tbl_ptr);

  driver->send_cfg_write(0x008, 0x1); // Start command
  ASSERT_TRUE(driver->wait_for_status_bit(/*SERVING_BIT=*/0, true, 200, 10))
    << "FSM failed to reach SERVING state for small range.";

  uint64_t alias_base   = tag_tbl_ptr;
  uint64_t alias_length = 4096;
  uint64_t num_reps     = 10;

  run_rand_rw_sequence( driver, alias_base, alias_length
                      , false // expect_user_tag
		      , RESP_DECERR // expected_b_resp
		      , RESP_DECERR // expected_r_resp
                      , num_reps
  );

  uint64_t status = driver->send_cfg_read(0x000);
  bool still_serving = status & 0x1;
  ASSERT_TRUE(still_serving) << "Hardware state machine crashed on automated aliased tag store fuzzing sequence.";

  // specifically try to forge a tag

  // initial untagged write
  uint64_t data_addr = small_base;
  driver->send_write(data_addr, 0xDEADBEEF, /*user=*/0, RESP_OKAY); // untagged
  auto [data_before, user_before, resp_before] = driver->send_read(data_addr);
  ASSERT_EQ(resp_before, RESP_OKAY);
  ASSERT_EQ(user_before, 0)
    << "Initial data write unexpectedly has a non-zero user field.";

  // corresponding tag-store address and forging attempt
  uint64_t tag_base = driver->send_cfg_read(0x020);
  uint64_t tag_addr = tag_base + ((data_addr - small_base) >> 4);
  driver->send_write(tag_addr, 0x1, /*user=*/0, RESP_DECERR);

  // verify forging did not happen
  auto [data_after, user_after, resp_after] = driver->send_read(data_addr);
  ASSERT_EQ(resp_after, RESP_OKAY);
  ASSERT_EQ(user_after, 0)
    << "Rejected tag-store write unexpectedly changed the data user field.";

  // check locking interface works
  uint64_t original_value = driver->send_cfg_read(0x10);
  // stop then config
  driver->send_cfg_write(0x008, 0x10000);
  tick(1);
  ASSERT_TRUE(driver->wait_for_status_bit(3 /*unconfigured */))
    << "Timeout waiting for FSM to return to UNCONFIGURED state.";
  tick(1);
  driver->send_cfg_write(0x08, 0x01000000); // lock
  driver->send_cfg_write(0x10, 0xDEADBEEF); // unsuccessful conf update
  uint64_t value_after_write = driver->send_cfg_read(0x10);

  ASSERT_EQ(value_after_write, original_value)
    << "Configuration register changed after config interface was locked. "
    << "Original: 0x" << std::hex << original_value
    << ", after write: 0x" << std::hex << value_after_write;

  delete driver;
}

//////////////////////
// main entry point //
////////////////////////////////////////////////////////////////////////////////

static void usage(const char *program_name)
{
  fputs("\
    Run Tag Controller Testbench.\n\
  ",
        stdout);
  fputs("\
  -v,                      Write vcd trace to FILE\n\
  ",
        stdout);
}

int main(int argc, char **argv)
{
  std::clock_t c_start = std::clock();
  auto t_start = std::chrono::high_resolution_clock::now();
  int option_index = 0;
  char *filename = nullptr;
#if VM_TRACE
  while ((option_index = getopt(argc, argv, "hv:")) != -1)
#else
  while ((option_index = getopt(argc, argv, "h")) != -1)
#endif
  {
    switch (option_index)
    {
    // Process long and short EMULATOR options
    case 'h':
      usage(argv[0]);
      return 1;
#if VM_TRACE
    case 'v':
    {
      dumpfolder = optarg;
      std::cout << "VCD dump folder path: " << dumpfolder << std::endl;
      break;
    }
#endif
    }
  }
  ::testing::InitGoogleTest(&argc, argv);
  auto ret = RUN_ALL_TESTS();
  std::clock_t c_end = std::clock();
  auto t_end = std::chrono::high_resolution_clock::now();
  std::cout << std::fixed << std::setprecision(2) << "CPU time used: "
            << 1000.0 * (c_end - c_start) / CLOCKS_PER_SEC << " ms\n"
            << "Wall clock time passed: "
            << std::chrono::duration<double, std::milli>(t_end - t_start).count()
            << " ms\n";
  return ret;
}
