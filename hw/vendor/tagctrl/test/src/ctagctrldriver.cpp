#include <ctagctrldriver.hpp>

CTagCtrlDriver::CTagCtrlDriver(Vtag_ctrl_testharness *dut)
{
    this->m_dut = dut;
    srand(time(0));
}

void CTagCtrlDriver::reset_slave()
{
    m_dut->cpu_aw_addr = 0;
    m_dut->cpu_aw_valid = 0;
    m_dut->cpu_w_valid = 0;
    m_dut->cpu_w_data = 0;
    m_dut->cpu_w_strb = 0;
    m_dut->cpu_w_last = 0;
    m_dut->cpu_b_ready = 0;
    m_dut->cpu_ar_valid = 0;
    m_dut->cpu_ar_addr = 0;
    m_dut->cpu_r_ready = 0;
}

void CTagCtrlDriver::send_aw(axi_ax_beat_t aw_beat)
{
    m_dut->cpu_aw_id = aw_beat.ax_id;
    m_dut->cpu_aw_addr = aw_beat.ax_addr;
    m_dut->cpu_aw_len = aw_beat.ax_len;
    m_dut->cpu_aw_size = aw_beat.ax_size;
    m_dut->cpu_aw_burst = aw_beat.ax_burst;
    m_dut->cpu_aw_user = aw_beat.ax_user;
    m_dut->cpu_aw_valid = 1;
}

void CTagCtrlDriver::send_w(axi_w_beat_t w_beat)
{
    m_dut->cpu_w_data = w_beat.w_data;
    m_dut->cpu_w_strb = w_beat.w_strb;
    m_dut->cpu_w_last = w_beat.w_last;
    m_dut->cpu_w_user = w_beat.w_user;
    m_dut->cpu_w_valid = 1;
}

void CTagCtrlDriver::send_ar(axi_ax_beat_t ar_beat)
{
    m_dut->cpu_ar_id = ar_beat.ax_id;
    m_dut->cpu_ar_addr = ar_beat.ax_addr;
    m_dut->cpu_ar_len = ar_beat.ax_len;
    m_dut->cpu_ar_size = ar_beat.ax_size;
    m_dut->cpu_ar_burst = ar_beat.ax_burst;
    m_dut->cpu_ar_user = ar_beat.ax_user;
    m_dut->cpu_ar_valid = 1;
}

axi_b_beat_t CTagCtrlDriver::recv_b()
{
    axi_b_beat_t b_beat{
        b_id : 0,
        b_resp : RESP_DECERR,
        b_user : 0,
        b_valid : 0
    };
    m_dut->cpu_b_ready = 1;
    if (m_dut->cpu_b_valid != 1) {
        b_beat.b_id = m_dut->cpu_b_id;
        b_beat.b_resp = (axi_resp_t)m_dut->cpu_b_resp;
        b_beat.b_user = m_dut->cpu_b_user;
        b_beat.b_valid = 1;
    }
    return b_beat;
}

axi_r_beat_t CTagCtrlDriver::recv_r()
{
    axi_r_beat_t r_beat = {0, 0, RESP_DECERR, 0, 0, 0};
    m_dut->cpu_r_ready = 1;
    if (m_dut->cpu_r_valid != 1) {
    r_beat.r_id = m_dut->cpu_r_id;
    r_beat.r_data = m_dut->cpu_r_data;
    r_beat.r_resp = static_cast<axi_resp_t>(m_dut->cpu_r_resp);
    r_beat.r_last = m_dut->cpu_r_last;
    r_beat.r_user = m_dut->cpu_r_user;
    r_beat.r_valid = 1;
    }
    return r_beat;
}

axi_ax_beat_t CTagCtrlDriver::rand_ax_beat()
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
axi_w_beat_t CTagCtrlDriver::rand_w_beat(int last)
{
    axi_w_beat_t w_beat;
    w_beat.w_strb = 0xff;
    w_beat.w_data = (rand() % (Vtag_ctrl_testharness_tag_ctrl_testharness::TagCacheMemBase - Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase + 1)) + Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase;
    w_beat.w_user = rand() % 2;
    w_beat.w_last = last;
    return w_beat;
}
