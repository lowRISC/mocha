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
#include <axi_types.h>

class CTagCtrlScb
{
private:
    std::deque<axi_ax_beat_t> m_axi_ar_beat_q;
    std::deque<axi_ax_beat_t> m_axi_aw_beat_q;
    std::deque<axi_w_beat_t> m_axi_w_beat_q;
    std::deque<axi_b_beat_t> m_axi_b_beat_q;
    std::deque<axi_r_beat_t> m_axi_r_beat_q;
    int m_mem_arr[Vtag_ctrl_testharness_tag_ctrl_testharness::TagCacheMemLength];
    int m_tag_arr[Vtag_ctrl_testharness_tag_ctrl_testharness::TagCacheMemLength / (Vtag_ctrl_testharness_tag_ctrl_testharness::CapSize * Vtag_ctrl_testharness_tag_ctrl_testharness::AxiDataWidth)];

public:
    CTagCtrlScb() {}
    ~CTagCtrlScb() {}

    void push_ar_beat(axi_ax_beat_t axi_ar_beat);
    void push_aw_beat(axi_ax_beat_t axi_aw_beat);
    void push_r_beat(axi_r_beat_t axi_r_beat);
    void push_w_beat(axi_w_beat_t axi_w_beat);
    void push_b_beat(axi_b_beat_t axi_b_beat);

    void scb_write();
    void scb_read();
};