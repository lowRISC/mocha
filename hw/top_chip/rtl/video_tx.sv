// Modified from HDMI demo from fpga4fun.com (c) fpga4fun.com & KNJN LLC 2013

module video_tx (
  // Clocking
  input  logic clk_pix_i,
  input  logic clk_tmds_i,

  // Reset
  input  logic rst_ni,

  // Frame buffer memory signals
  output logic        mem_en,
  output logic [16:0] mem_addr,
  input  logic [63:0] mem_data,

  // Logo ROM memory signals
  output logic        logo_rom_en,
  output logic [17:0] logo_rom_addr,
  input  logic  [7:0] logo_rom_data,

  // Differential Output
  output logic [2:0] dvi_data_po,
  output logic [2:0] dvi_data_no,
  output logic       dvi_pix_clk_po,
  output logic       dvi_pix_clk_no
);
  // Local parameters.
  localparam int unsigned SERIAL_RATIO             = 10; // 8b10b serialization ratio
  localparam int unsigned BPC                      = 8;  // Bits per channel
  localparam int unsigned CHANNELS                 = 3;
  localparam int unsigned FRAME_BUFFER_WIDTH       = 512;
  localparam int unsigned FRAME_BUFFER_HEIGHT      = 1024;
  localparam int unsigned FRAME_BUFFER_WIDTH_BITS  = $clog2(FRAME_BUFFER_WIDTH);
  localparam int unsigned FRAME_BUFFER_HEIGHT_BITS = $clog2(FRAME_BUFFER_HEIGHT);
  localparam int unsigned LOGO_WIDTH       = 1024;
  localparam int unsigned LOGO_HEIGHT      = 765;
  localparam int unsigned LOGO_X_OFFSET    = 800; // Must be divisible by 4
  localparam int unsigned LOGO_Y_OFFSET    = 157;
  localparam int unsigned LOGO_WIDTH_BITS  = $clog2(LOGO_WIDTH);
  localparam int unsigned LOGO_HEIGHT_BITS = $clog2(LOGO_HEIGHT);

  // Video mode parameters
  // CVT-RB 1080p60 +H -V 138.5MHz pixel clock
  localparam int unsigned HDISP            = 1920;
  localparam int unsigned HSYNCSTART       = 1968;
  localparam int unsigned HSYNCEND         = 2000;
  localparam int unsigned HTOTAL           = 2080;
  localparam bit          HSYNC_ACTIVE_LOW = 0;
  localparam int unsigned VDISP            = 1080;
  localparam int unsigned VSYNCSTART       = 1083;
  localparam int unsigned VSYNCEND         = 1088;
  localparam int unsigned VTOTAL           = 1111;
  localparam bit          VSYNC_ACTIVE_LOW = 1;

  localparam int unsigned PX_COUNTER_BITS = $clog2((HTOTAL > VTOTAL) ? HTOTAL : VTOTAL);

  // Video timing registers
  logic [PX_COUNTER_BITS-1:0] counter_x;
  logic [PX_COUNTER_BITS-1:0] counter_y;
  logic                       h_sync;
  logic                       v_sync;
  logic                       video_area;

  // ROM pixel signals
  logic [BPC-1:0] rom_data_red   [4];
  logic [BPC-1:0] rom_data_green [4];
  logic [BPC-1:0] rom_data_blue  [4];

  // Pixel data registers
  logic [BPC-1:0] red;
  logic [BPC-1:0] green;
  logic [BPC-1:0] blue;

  // Test pattern registers
  logic [1:0]     pattern_en_ctr;
  logic [29:0]    pattern_offset;

  // Test pattern signals
  logic [9:0]     disp_count_x;
  logic [9:0]     disp_count_y;
  logic [BPC-1:0] W;
  logic [BPC-1:0] A;

  // Encoded TMDS signals
  logic [SERIAL_RATIO-1:0] tmds_red;
  logic [SERIAL_RATIO-1:0] tmds_green;
  logic [SERIAL_RATIO-1:0] tmds_blue;

  // Serialisation signals
  logic [(CHANNELS * SERIAL_RATIO)-1:0] serdes_mixed_parallel_in;

  // Video timing generation
  always_ff @(posedge clk_pix_i or negedge rst_ni) begin
    if (!rst_ni) begin
      video_area <= 1'b0;
      h_sync     <= 1'b0;
      v_sync     <= 1'b0;
    end else begin
      video_area <= (counter_x < HDISP) && (counter_y < VDISP);
      h_sync     <= (counter_x >= HSYNCSTART) && (counter_x < HSYNCEND);
      v_sync     <= (counter_y >= VSYNCSTART) && (counter_y < VSYNCEND);
    end
  end

  always_ff @(posedge clk_pix_i or negedge rst_ni) begin
    if (!rst_ni) begin
      counter_x <= '0;
      counter_y <= '0;
    end else begin
      counter_x <= (counter_x == (HTOTAL - 1)) ? '0 : (counter_x + 1);
      if (counter_x == (HTOTAL - 1)) begin
        counter_y <= (counter_y == (VTOTAL - 1)) ? '0 : (counter_y + 1);
      end
    end
  end

  // Pixel data generation

  // Slow down pattern movement
  always_ff @(posedge clk_pix_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pattern_en_ctr <= '0;
    end else begin
      pattern_en_ctr <= pattern_en_ctr + 1;
    end
  end

  // Displaced coordinates for test pattern
  always_ff @(posedge clk_pix_i or negedge rst_ni) begin
    if (!rst_ni) begin
      pattern_offset <= '0;
    end else if (pattern_en_ctr == '0) begin
      pattern_offset <= pattern_offset + 1;
    end
  end

  assign disp_count_x = counter_x[9:0] - pattern_offset[29 -: 10];
  assign disp_count_y = counter_y[9:0] + pattern_offset[29 -: 10];
  assign W = {BPC{disp_count_x[7:0] == disp_count_y[7:0]}};
  assign A = {BPC{disp_count_x[7:5] == 3'h2 && disp_count_y[7:5] == 3'h2}};

  // ROM data to RGB mapping
  always_comb begin
    for (int i=0; i < 4; ++i) begin
      // case (logo_rom_data[2*i +: 2])
      //   2'h0: begin
      //     rom_data_red[i]   = 32;
      //     rom_data_green[i] = 38;
      //     rom_data_blue[i]  = 44;
      //   end
      //   2'h1: begin
      //     rom_data_red[i]   = 224;
      //     rom_data_green[i] = 56;
      //     rom_data_blue[i]  = 79;
      //   end
      //   2'h2: begin
      //     rom_data_red[i]   = 227;
      //     rom_data_green[i] = 227;
      //     rom_data_blue[i]  = 227;
      //   end
      //   default: begin
      //     rom_data_red[i]   = 0;
      //     rom_data_green[i] = 0;
      //     rom_data_blue[i]  = 0;
      //   end
      // endcase
      if (logo_rom_data[2*i + 1] == 1'b0) begin
        rom_data_red[i]   = 0;
        rom_data_green[i] = 0;
        rom_data_blue[i]  = 0;
      end else begin
        // Change palette based on Y
        if (counter_y < (LOGO_Y_OFFSET + 530)) begin
          rom_data_red[i]   = 224;
          rom_data_green[i] = 56;
          rom_data_blue[i]  = 79;
        end else begin
          rom_data_red[i]   = 227;
          rom_data_green[i] = 227;
          rom_data_blue[i]  = 227;
        end
      end
    end
  end

  // Always read
  assign mem_en = 1;
  assign logo_rom_en = 1;

  always_ff @(posedge clk_pix_i or negedge rst_ni) begin
    if (!rst_ni) begin
      red   <= '0;
      green <= '0;
      blue  <= '0;
      mem_addr <= '0;
      logo_rom_addr <= '0;
    end else if (counter_x < FRAME_BUFFER_WIDTH && counter_y < FRAME_BUFFER_HEIGHT) begin // Inside frame buffer
      // Display current pixel
      // Read from memory
      case (counter_x[1:0])
        2'h0: begin
          red   <= {mem_data[(0*16 +  0) +: 5], mem_data[(0*16 +  0 + 2) +: 3]};
          green <= {mem_data[(0*16 +  5) +: 6], mem_data[(0*16 +  5 + 4) +: 2]};
          blue  <= {mem_data[(0*16 + 11) +: 5], mem_data[(0*16 + 11 + 2) +: 3]};
        end
        2'h1: begin
          red   <= {mem_data[(1*16 +  0) +: 5], mem_data[(1*16 +  0 + 2) +: 3]};
          green <= {mem_data[(1*16 +  5) +: 6], mem_data[(1*16 +  5 + 4) +: 2]};
          blue  <= {mem_data[(1*16 + 11) +: 5], mem_data[(1*16 + 11 + 2) +: 3]};
        end
        2'h2: begin
          red   <= {mem_data[(2*16 +  0) +: 5], mem_data[(2*16 +  0 + 2) +: 3]};
          green <= {mem_data[(2*16 +  5) +: 6], mem_data[(2*16 +  5 + 4) +: 2]};
          blue  <= {mem_data[(2*16 + 11) +: 5], mem_data[(2*16 + 11 + 2) +: 3]};
        end
        2'h3: begin
          red   <= {mem_data[(3*16 +  0) +: 5], mem_data[(3*16 +  0 + 2) +: 3]};
          green <= {mem_data[(3*16 +  5) +: 6], mem_data[(3*16 +  5 + 4) +: 2]};
          blue  <= {mem_data[(3*16 + 11) +: 5], mem_data[(3*16 + 11 + 2) +: 3]};
        end
        default: begin end
      endcase

      // Read next pixel
      if (counter_x[FRAME_BUFFER_WIDTH_BITS-1:0] == '1 && (counter_y + 1) == FRAME_BUFFER_HEIGHT) begin
        // Last pixel
        mem_addr <= '0;
      end else if (counter_x[1:0] == 2'b00) begin
        mem_addr <= {counter_y[FRAME_BUFFER_HEIGHT_BITS-1:0], counter_x[FRAME_BUFFER_WIDTH_BITS-1:2]} + 1;
      end
    end else if (counter_x >= LOGO_X_OFFSET && counter_x < (LOGO_X_OFFSET + LOGO_WIDTH) && counter_y >= LOGO_Y_OFFSET && counter_y < (LOGO_Y_OFFSET + LOGO_HEIGHT)) begin // Inside logo
      // Display ROM current pixel
      // Read from memory
      case (counter_x[1:0])
        2'h0: begin
          red   <= rom_data_red[0];
          green <= rom_data_green[0];
          blue  <= rom_data_blue[0];
        end
        2'h1: begin
          red   <= rom_data_red[1];
          green <= rom_data_green[1];
          blue  <= rom_data_blue[1];
        end
        2'h2: begin
          red   <= rom_data_red[2];
          green <= rom_data_green[2];
          blue  <= rom_data_blue[2];
        end
        2'h3: begin
          red   <= rom_data_red[3];
          green <= rom_data_green[3];
          blue  <= rom_data_blue[3];
        end
        default: begin end
      endcase

      // Read next pixel
      if ((counter_x + 1) == (LOGO_X_OFFSET + LOGO_WIDTH) && (counter_y + 1) == (LOGO_Y_OFFSET + LOGO_HEIGHT)) begin
        // Last pixel
        logo_rom_addr <= '0;
      end else if (counter_x[1:0] == 2'b00) begin
        logo_rom_addr <= logo_rom_addr + 1;
      end
    end else begin // Outside frame buffer and logo
      // Display test pattern
      red   <= ({disp_count_x[5:0] & {6{disp_count_y[4:3] == ~disp_count_x[4:3]}}, 2'b00} | W) & ~A;
      green <= (disp_count_x[7:0] & {BPC{disp_count_y[6]}} | W) & ~A;
      blue  <= disp_count_y[7:0] | W | A;
    end 
  end

  // TMDS Encoding
  tmds_enc u_r_enc(
    .clk(clk_pix_i),
    .VD(red),
    .CD({VSYNC_ACTIVE_LOW, HSYNC_ACTIVE_LOW}),
    .VDE(video_area),
    .TMDS(tmds_red)
  );
  tmds_enc u_g_enc(
    .clk(clk_pix_i),
    .VD(green),
    .CD({VSYNC_ACTIVE_LOW, HSYNC_ACTIVE_LOW}),
    .VDE(video_area),
    .TMDS(tmds_green)
  );
  tmds_enc u_b_enc(
    .clk(clk_pix_i),
    .VD(blue),
    .CD({v_sync ^ VSYNC_ACTIVE_LOW, h_sync ^ HSYNC_ACTIVE_LOW}),
    .VDE(video_area),
    .TMDS(tmds_blue)
  );

  // Serialisation
  always_comb begin
    for (int i = 0; i < SERIAL_RATIO; ++i) begin
      serdes_mixed_parallel_in[i * CHANNELS + 0] = tmds_blue[i];
      serdes_mixed_parallel_in[i * CHANNELS + 1] = tmds_green[i];
      serdes_mixed_parallel_in[i * CHANNELS + 2] = tmds_red[i];
    end
  end

  selectio_wiz_0 u_serdes(
    .clk_in               ( clk_tmds_i               ),
    .clk_div_in           ( clk_pix_i                ),
    .clk_reset            ( ~rst_ni                  ),
    .io_reset             ( ~rst_ni                  ),
    .data_out_from_device ( serdes_mixed_parallel_in ),
    .data_out_to_pins_p   ( dvi_data_po              ),
    .data_out_to_pins_n   ( dvi_data_no              ),
    .clk_to_pins_p        ( dvi_pix_clk_po           ),
    .clk_to_pins_n        ( dvi_pix_clk_no           )
  );
endmodule
