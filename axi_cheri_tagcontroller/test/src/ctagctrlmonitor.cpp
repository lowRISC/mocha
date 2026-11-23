#include <ctagctrlmonitor.hpp>

CTagCtrlMonitor::CTagCtrlMonitor(Vtag_ctrl_testharness *dut, CTagCtrlScb *scb)
{
    this->m_dut = dut;
    this->m_scb = scb;
}

void CTagCtrlMonitor::mon_aw()
{
    axi_ax_beat_t aw_beat;
    if (m_dut->cpu_aw_ready == 1 && m_dut->cpu_aw_valid)
    {
        aw_beat.ax_id = m_dut->cpu_aw_id;
        aw_beat.ax_addr = m_dut->cpu_aw_addr;
        aw_beat.ax_len = m_dut->cpu_aw_len;
        aw_beat.ax_size = m_dut->cpu_aw_size;
        aw_beat.ax_burst = (axi_burst_t)m_dut->cpu_aw_burst;
        aw_beat.ax_user = m_dut->cpu_aw_user;
        if (m_scb != nullptr)
        {
            m_scb->push_aw_beat(aw_beat);
        }
    }
}

void CTagCtrlMonitor::mon_w()
{
    axi_w_beat_t w_beat;
    if (m_dut->cpu_w_ready == 1 && m_dut->cpu_w_valid == 1)
    {
        w_beat.w_data = m_dut->cpu_w_data;
        w_beat.w_strb = m_dut->cpu_w_strb;
        w_beat.w_last = m_dut->cpu_w_last;
        w_beat.w_user = m_dut->cpu_w_user;
        m_scb->push_w_beat(w_beat);
    }
}

void CTagCtrlMonitor::mon_ar()
{
    axi_ax_beat_t ar_beat;
    if (m_dut->cpu_ar_ready == 1 && m_dut->cpu_aw_valid == 1)
    {
        ar_beat.ax_id = m_dut->cpu_ar_id;
        ar_beat.ax_addr = m_dut->cpu_ar_addr;
        ar_beat.ax_len = m_dut->cpu_ar_len;
        ar_beat.ax_size = m_dut->cpu_ar_size;
        ar_beat.ax_burst = static_cast<axi_burst_t>(m_dut->cpu_ar_burst);
        ar_beat.ax_user = m_dut->cpu_ar_user;
        m_scb->push_ar_beat(ar_beat);
    }
}

void CTagCtrlMonitor::mon_b()
{
    axi_b_beat_t b_beat;
    if (m_dut->cpu_b_valid == 1 && m_dut->cpu_b_ready == 1)
    {
        b_beat.b_id = m_dut->cpu_b_id;
        b_beat.b_resp = (axi_resp_t)m_dut->cpu_b_resp;
        b_beat.b_user = m_dut->cpu_b_user;
        m_scb->push_b_beat(b_beat);
    }
}

void CTagCtrlMonitor::mon_r()
{
    axi_r_beat_t r_beat = {0, 0, RESP_DECERR, 0, 0, 0};
    m_dut->cpu_r_ready = 1;
    if (m_dut->cpu_r_valid == 1 && m_dut->cpu_r_ready == 1)
    {
        r_beat.r_id = m_dut->cpu_r_id;
        r_beat.r_data = m_dut->cpu_r_data;
        r_beat.r_resp = static_cast<axi_resp_t>(m_dut->cpu_r_resp);
        r_beat.r_last = m_dut->cpu_r_last;
        r_beat.r_user = m_dut->cpu_r_user;
        r_beat.r_valid = 1;
        m_scb->push_r_beat(r_beat);
    }
}