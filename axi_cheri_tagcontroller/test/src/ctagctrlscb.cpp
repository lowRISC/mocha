#include <ctagctrlscb.hpp>

CTagCtrlScb::CTagCtrlScb()
{
}

void CTagCtrlScb::push_ar_beat(axi_ax_beat_t axi_ar_beat)
{
    m_axi_ar_beat_q.push_back(axi_ar_beat);
}
void CTagCtrlScb::push_aw_beat(axi_ax_beat_t axi_aw_beat)
{
    m_axi_aw_beat_q.push_back(axi_aw_beat);
}
void CTagCtrlScb::push_r_beat(axi_r_beat_t axi_r_beat)
{
    m_axi_r_beat_q.push_back(axi_r_beat);
}
void CTagCtrlScb::push_w_beat(axi_w_beat_t axi_w_beat)
{
    m_axi_w_beat_q.push_back(axi_w_beat);
}
void CTagCtrlScb::push_b_beat(axi_b_beat_t axi_b_beat)
{
    m_axi_b_beat_q.push_back(axi_b_beat);
}

void CTagCtrlScb::scb_write()
{
    // See if
    static bool write_inflight = false;
    static bool b_recv = false;
    int addr = 0;
    int tag_addr = 0;
    int tag_idx = 0;
    int cnt = 0;
    axi_ax_beat_t aw_beat;
    axi_w_beat_t w_beat;
    axi_b_beat_t b_beat;

    if (!m_axi_aw_beat_q.empty() && !write_inflight)
    {
        aw_beat = m_axi_aw_beat_q.front();
        m_axi_aw_beat_q.pop_front();
        write_inflight = true;
        addr = aw_beat.ax_addr;
    }
    if (write_inflight)
    {
        if (!m_axi_b_beat_q.empty() && !b_recv)
        {
            b_beat = m_axi_b_beat_q.front();
            m_axi_b_beat_q.pop_front();
            b_recv = true;
            ASSERT_EQ(b_beat.b_id, aw_beat.ax_id);
            ASSERT_EQ(b_beat.b_resp, RESP_OKAY);
            ASSERT_EQ(b_beat.b_user, 0);
        }
        if (b_recv)
        {
            if (!m_axi_w_beat_q.empty())
            {
                w_beat = m_axi_w_beat_q.front();
                m_axi_w_beat_q.pop_front();
                addr = (aw_beat.ax_addr - Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase) + (cnt * 8);
                tag_addr = (Vtag_ctrl_testharness_tag_ctrl_testharness::TagCacheMemBase + ((aw_beat.ax_addr - Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase) >> 4));
                tag_idx = (Vtag_ctrl_testharness_tag_ctrl_testharness::TagCacheMemBase + (aw_beat.ax_addr - Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase)) & (7);
                cnt++;
                m_mem_arr[addr] = w_beat.w_data;
                m_tag_arr[tag_addr] = m_tag_arr[tag_addr] | (w_beat.w_user << tag_idx);
                ASSERT_EQ(w_beat.w_data, m_mem_arr[addr]);
                ASSERT_EQ(w_beat.w_user, (m_tag_arr[tag_addr] >> tag_idx) & 1);
                if (cnt == aw_beat.ax_len)
                {
                    ASSERT_EQ(w_beat.w_last, 1);
                    b_recv = false;
                    write_inflight = false;
                    cnt = 0;
                }
            }
        }
    }
}
void CTagCtrlScb::scb_read()
{
    // See if
    static bool read_inflight = false;
    int addr = 0;
    int cnt = 0;
    int tag_idx = 0;
    int tag_addr = 0;
    axi_ax_beat_t ar_beat;
    axi_r_beat_t r_beat;
    if (!m_axi_ar_beat_q.empty() && !read_inflight)
    {
        ar_beat = m_axi_ar_beat_q.front();
        m_axi_ar_beat_q.pop_front();
        read_inflight = true;
        addr = ar_beat.ax_addr;
    }
    if (read_inflight)
    {
        if (!m_axi_r_beat_q.empty())
        {
            r_beat = m_axi_r_beat_q.front();
            m_axi_r_beat_q.pop_front();
            addr = (ar_beat.ax_addr - Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase) + (cnt * 8);
            tag_addr = (Vtag_ctrl_testharness_tag_ctrl_testharness::TagCacheMemBase + ((ar_beat.ax_addr - Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase) >> 4));
            tag_idx = (Vtag_ctrl_testharness_tag_ctrl_testharness::TagCacheMemBase + (ar_beat.ax_addr - Vtag_ctrl_testharness_tag_ctrl_testharness::DRAMMemBase)) & (7);
            cnt++;
            ASSERT_EQ(r_beat.r_id, ar_beat.ax_id);
            ASSERT_EQ(r_beat.r_data, m_mem_arr[addr]);
            ASSERT_EQ(r_beat.r_user, (m_tag_arr[tag_addr] >> tag_idx) & 1);
            if (cnt == ar_beat.ax_len)
            {
                ASSERT_EQ(r_beat.r_last, 1);
                read_inflight = false;
                cnt = 0;
            }
        }
    }
}