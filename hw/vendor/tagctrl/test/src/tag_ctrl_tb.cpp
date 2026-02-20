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

#define MAX_NUM_REPS 500

static vluint64_t main_time = 0;
static std::string dumpfolder = "/test/logs/";
static std::string dumpfile = "dump.vcd";

class CTagctrl_tb : public ::testing::Test
{
protected:
  Vtag_ctrl_testharness *top;
  VerilatedVcdC *tfp;

  void SetUp()
  {
    main_time = 0;
    top = new (Vtag_ctrl_testharness);
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
    delete top;
#if VM_TRACE
    tfp->close();
    delete tfp;
#endif
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
    srand(time(0));
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

  axi_ax_beat_t rand_ax_beat()
  {
    axi_ax_beat_t ax_beat;
    ax_beat.ax_id = rand() % (int)fabs((pow(2, Vtag_ctrl_testharness_tag_ctrl_testharness::AxiIdWidth)));
    ax_beat.ax_addr = (rand() % (Vtag_ctrl_testharness_tag_ctrl_testharness::TagCacheMemBase - Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase + 1)) + Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase;
    // align to 4KiB
    ax_beat.ax_addr = ax_beat.ax_addr & ~(4095);
    ax_beat.ax_len = (uint8_t)(rand() % 255);
    ax_beat.ax_size = 3; // always 64-bit for now
    ax_beat.ax_burst = BURST_INCR;
    ax_beat.ax_user = 0;
    return ax_beat;
  }
  axi_w_beat_t rand_w_beat(int last)
  {
    axi_w_beat_t w_beat;
    w_beat.w_strb = 0xff;
    w_beat.w_data = (rand() % (Vtag_ctrl_testharness_tag_ctrl_testharness::TagCacheMemBase - Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase + 1)) + Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase;
    w_beat.w_user = rand() % 2;
    w_beat.w_last = last;
    return w_beat;
  }
};

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

TEST_F(CTagctrl_tb, Rand_AXI_RW_OP)
{
  CTagCtrlDriver_tb *driver = new CTagCtrlDriver_tb(top, this);
  axi_ax_beat_t aw_beat;
  axi_ax_beat_t ar_beat;
  axi_w_beat_t w_beat, last_w_beat;
  axi_r_beat_t r_beat;
  axi_b_beat_t b_beat;
  std::deque<axi_w_beat_t> axi_w_beat_q;
  tick(2500);
  for (uint64_t i = 0; i < MAX_NUM_REPS; i++)
  {
    // Generate random aw beat and ar beat
    aw_beat = driver->rand_ax_beat();
    ar_beat = aw_beat;
    // Reset CPU slave interface
    driver->reset_slave();
    // Send aw beat
    driver->send_aw(aw_beat);
    int last = 0;
    uint8_t len = aw_beat.ax_len;
    uint64_t addr = 0;
    uint64_t last_addr = 0;
    for (uint64_t i = 0; i <= len; i++)
    {
      // Check if it is the last beat
      last = (i == len) ? 1 : 0;
      // Generate a random write beat
      w_beat = driver->rand_w_beat(last);
      // compute beat address
      addr = (aw_beat.ax_addr + i * 8) >> (int)fabs(log2(Vtag_ctrl_testharness_tag_ctrl_testharness::CapSize / 8));
      // Store last beat address
      if (i == 0)
        last_addr = aw_beat.ax_addr;
      else
        last_addr = (aw_beat.ax_addr + (i - 1) * 8) >> (int)fabs(log2(Vtag_ctrl_testharness_tag_ctrl_testharness::CapSize / 8));
      // Check if this beat + the last form a 128-bit data value
      // if so the user value or the capability bit should be the same
      if (last_addr == addr)
        w_beat.w_user = last_w_beat.w_user;
      driver->send_w(w_beat);
      axi_w_beat_q.push_back(w_beat);
      last_w_beat = w_beat;
    }
    // Receive the b response
    b_beat = driver->recv_b();
    // Assert if the transaction ID is correct
    ASSERT_EQ(b_beat.b_id, aw_beat.ax_id);
    // Assert if we got a OKAY response
    ASSERT_EQ(b_beat.b_resp, RESP_OKAY);
    driver->send_ar(ar_beat);
    for (uint64_t i = 0; i <= len; i++)
    {
      r_beat = driver->recv_r();
      ASSERT_EQ(r_beat.r_id, ar_beat.ax_id);
      // Get the write beat to perform the assertion
      w_beat = axi_w_beat_q.front();
      axi_w_beat_q.pop_front();
      ASSERT_EQ(r_beat.r_data, w_beat.w_data);
      ASSERT_EQ(r_beat.r_resp, RESP_OKAY);
      if (i == len)
        ASSERT_EQ(r_beat.r_last, 1);
      else
        ASSERT_EQ(r_beat.r_last, 0);
      ASSERT_EQ(r_beat.r_user, w_beat.w_user);
    }
  }
  delete driver;
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
