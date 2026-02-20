#pragma once
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

class CTagCtrlMonitor
{
private:
  Vtag_ctrl_testharness *m_dut;
  CTagCtrlScb *m_scb;

public:
  CTagCtrlMonitor(Vtag_ctrl_testharness *dut, CTagCtrlScb *scb);
  ~CTagCtrlMonitor();

  void mon_aw();
  void mon_w();
  void mon_ar();
  void mon_b();
  void mon_r();
};