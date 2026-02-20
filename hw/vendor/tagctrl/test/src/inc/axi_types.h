#pragma once
#include <cstdlib>

enum axi_resp_t
{
  RESP_OKAY,
  RESP_EXOKAY,
  RESP_SLVERR,
  RESP_DECERR
};
enum axi_burst_t
{
  BURST_FIXED,
  BURST_INCR,
  BURST_WRAP
};

typedef struct axi_r_resp
{
  unsigned long int axi_data;
  axi_resp_t axi_resp;
} axi_r_resp_t;

typedef struct axi_ax_beat
{
  unsigned int ax_id;
  unsigned long int ax_addr;
  uint8_t ax_len;
  uint8_t ax_size;
  axi_burst_t ax_burst;
  unsigned int ax_user;
} axi_ax_beat_t;

typedef struct axi_w_beat
{
  unsigned long int w_data;
  unsigned int w_strb;
  unsigned int w_last;
  unsigned int w_user;
} axi_w_beat_t;

typedef struct axi_b_beat
{
  unsigned int b_id;
  axi_resp_t b_resp;
  unsigned int b_user;
  unsigned int b_valid;
} axi_b_beat_t;

typedef struct axi_r_beat
{
  unsigned int r_id;
  unsigned long int r_data;
  axi_resp_t r_resp;
  unsigned int r_last;
  unsigned int r_user;
  unsigned int r_valid;
} axi_r_beat_t;