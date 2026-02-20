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
#include <ctagctrlscb.hpp> 
#include <axi_types.h>

class CTagCtrlDriver
{
private:
  Vtag_ctrl_testharness *m_dut;

public:
  CTagCtrlDriver(Vtag_ctrl_testharness *dut, CTagctrl_tb *tb);
  ~CTagCtrlDriver();

  void reset_slave();
  void send_aw(axi_ax_beat_t aw_beat);
  void send_w(axi_w_beat_t w_beat);
  void send_ar(axi_ax_beat_t ar_beat);
  axi_b_beat_t recv_b();
  axi_r_beat_t recv_r();
  axi_ax_beat_t rand_ax_beat();
  axi_w_beat_t rand_w_beat(int last);
};