// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
// Thomas Benz <tbenz@iis.ee.ethz.ch>

`include "common_cells/assertions.svh"
`include "common_cells/registers.svh"
`include "axi/typedef.svh"

/// Simple VGA IP capable of drawing frames from an external framebuffer.
module axi_vga #(
  parameter int unsigned RedWidth     = 5,
  parameter int unsigned GreenWidth   = 6,
  parameter int unsigned BlueWidth    = 5,
  parameter int unsigned HCountWidth  = 32,
  parameter int unsigned VCountWidth  = 32,
  parameter int unsigned AXIAddrWidth = 64,
  parameter int unsigned AXIDataWidth = 64,
  parameter int unsigned AXIIdWidth   = 2,
  parameter int unsigned AXIUserWidth = 1,
  parameter int unsigned AXIStrbWidth = 8,
  parameter int unsigned BufferDepth  = 32,
  parameter int unsigned MaxReadTxns  = 24,
  parameter type axi_req_t            = logic,
  parameter type axi_resp_t           = logic,
  parameter type reg_req_t            = logic,
  parameter type reg_resp_t           = logic
)(
  input logic                     clk_i,
  input logic                     rst_ni,

  input logic                     test_mode_en_i,

  // Regbus config ports
  input  reg_req_t                reg_req_i,
  output reg_resp_t               reg_rsp_o,

  // AXI Data ports
  output axi_req_t                axi_req_o,
  input  axi_resp_t               axi_resp_i,

  // Interrupts
  output logic frame_done_o,  // timing FSM signals end of visible area
  output logic vsync_start_o, // timing FSM signals start of VSYNC pulse

  // VGA interface
  output logic                    hsync_o,
  output logic                    vsync_o,
  output logic [RedWidth-1:0]     red_o,
  output logic [GreenWidth-1:0]   green_o,
  output logic [BlueWidth-1:0]    blue_o
);

  typedef logic [AXIAddrWidth-1:0] axi_addr_t;
  typedef logic [AXIDataWidth-1:0] axi_data_t;
  typedef logic [AXIIdWidth-1:0]   axi_id_t;
  typedef logic [AXIStrbWidth-1:0] axi_strb_t;
  typedef logic [AXIUserWidth-1:0] axi_user_t;

  `AXI_TYPEDEF_AW_CHAN_T(axi_aw_chan_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_W_CHAN_T(axi_w_chan_t, axi_data_t, axi_strb_t, axi_user_t)
  `AXI_TYPEDEF_B_CHAN_T(axi_b_chan_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_AR_CHAN_T(axi_ar_chan_t, axi_addr_t, axi_id_t, axi_user_t)
  `AXI_TYPEDEF_R_CHAN_T(axi_r_chan_t, axi_data_t, axi_id_t, axi_user_t)

  /// credit counter width
  localparam int unsigned CounterWidth = $clog2(BufferDepth + 32'd1);
  /// credit counter type
  typedef logic [CounterWidth-1:0] counter_t;

  logic [7:0] clk_div;
  logic [7:0] clk_cnt_d, clk_cnt_q;

  axi_vga_reg_pkg::axi_vga_reg2hw_t reg2hw;

  axi_req_t  axi_req,  axi_req_fetcher, axi_req_split;
  axi_resp_t axi_resp, axi_resp_fetcher, axi_resp_split;
  axi_r_chan_t resp_fifo_inp, resp_fifo_out;
  logic axi_req_cc_ar_valid, axi_resp_cc_ar_ready; // credit counter stream_join signals

  logic     read_completed;
  logic     credit_valid;
  logic     credit_ready;
  counter_t counter_d, counter_q;
  counter_t fifo_usage;
  logic     first_fetcher_req;

  logic [RedWidth-1:0]   red;
  logic [GreenWidth-1:0] green;
  logic [BlueWidth-1:0]  blue;
  logic valid, ready;

  // Clock divider constant
  assign clk_div = |reg2hw.clk_div.q ? reg2hw.clk_div.q : 1;

  // Cycle counter to scale the incoming clock
  assign clk_cnt_d = (clk_cnt_q < (clk_div-1)) ? clk_cnt_q + 8'b0000_0001 : 8'b0;

  // Regbus register interface
  axi_vga_reg_top #(
    .reg_req_t      ( reg_req_t           ),
    .reg_rsp_t      ( reg_resp_t          ),
    .AW             ( 6                   )
  ) i_axi_vga_register_file (
    .clk_i,
    .rst_ni,
    .reg_req_i,
    .reg_rsp_o,
    // To HW
    .reg2hw         ( reg2hw              ), // Write
    // Config
    .devmode_i      ( '1                  )  // Explicit error for unmapped register access
  );
  // TODO: reject burst split length larger than BufferDepth

  // FSM managing the VGA signals
  axi_vga_timing_fsm #(
    .RedWidth       ( RedWidth            ),
    .GreenWidth     ( GreenWidth          ),
    .BlueWidth      ( BlueWidth           ),
    .HCountWidth    ( HCountWidth         ),
    .VCountWidth    ( VCountWidth         )
  ) i_axi_vga_timing_fsm (
    .clk_i,
    .rst_ni,

    .fsm_en_i       ( clk_cnt_q == 0      ),
    .reg2hw_i       ( reg2hw              ),

    // Data input
    .red_i          ( red                 ),
    .green_i        ( green               ),
    .blue_i         ( blue                ),
    .valid_i        ( valid               ),
    .ready_o        ( ready               ),

    // Interrupts
    .frame_done_o,
    .vsync_start_o,

    // VGA interface
    .hsync_o,
    .vsync_o,
    .red_o,
    .green_o,
    .blue_o
  );

  axi_vga_fetcher #(
    .RedWidth       ( RedWidth            ),
    .GreenWidth     ( GreenWidth          ),
    .BlueWidth      ( BlueWidth           ),
    .AXIAddrWidth   ( AXIAddrWidth        ),
    .AXIDataWidth   ( AXIDataWidth        ),
    .AXIStrbWidth   ( AXIStrbWidth        ),
    .axi_req_t      ( axi_req_t           ),
    .axi_resp_t     ( axi_resp_t          )
  ) i_axi_vga_fetcher (
    .clk_i,
    .rst_ni,
    .enable_i       ( reg2hw.control.enable.q ),

    .axi_req_o      ( axi_req_fetcher     ),
    .axi_resp_i     ( axi_resp_fetcher    ),

    .start_addr_i   ( {reg2hw.start_addr_high.q, reg2hw.start_addr_low.q}),
    .frame_size_i   ( reg2hw.frame_size.q ),
    .burst_len_i    ( reg2hw.burst_len.q  ),
    .burst_split_len_i ( reg2hw.burst_split_len.q  ),
    .red_o          ( red                 ),
    .green_o        ( green               ),
    .blue_o         ( blue                ),
    .valid_o        ( valid               ),
    .ready_i        ( ready               ),
    .frame_done_i   ( frame_done_o        ),
    .vsync_start_i  ( vsync_start_o       )
  );

  // Add stream FIFO in the response channel to buffer requested data
  // all other channels are just passed through
  // fetcher request pass through
  assign axi_req_split.aw       = axi_req_fetcher.aw;
  assign axi_req_split.aw_valid = axi_req_fetcher.aw_valid;
  assign axi_req_split.w        = axi_req_fetcher.w;
  assign axi_req_split.w_valid  = axi_req_fetcher.w_valid;
  assign axi_req_split.b_ready  = axi_req_fetcher.b_ready;
  assign axi_req_split.ar       = axi_req_fetcher.ar;
  assign axi_req_split.ar_valid = axi_req_fetcher.ar_valid;
  // splitter response pass through
  assign axi_resp_fetcher.ar_ready = axi_resp_split.ar_ready;
  assign axi_resp_fetcher.aw_ready = axi_resp_split.aw_ready;
  assign axi_resp_fetcher.w_ready  = axi_resp_split.w_ready;
  assign axi_resp_fetcher.b_valid  = axi_resp_split.b_valid;
  assign axi_resp_fetcher.b        = axi_resp_split.b;

  stream_fifo #(
    .FALL_THROUGH ( 32'd0               ),
    .DEPTH        ( BufferDepth + 32'd1 ), // +1 as the FIFO cannot be pushed and popped in-cycle
    .T            ( axi_r_chan_t        )
  ) i_stream_fifo (
    .clk_i,
    .rst_ni,
    .flush_i    ( frame_done_o   ),
    .testmode_i ( test_mode_en_i ),
    .usage_o    ( fifo_usage     ),
    // from splitter
    .data_i     ( axi_resp_split.r       ),
    .valid_i    ( axi_resp_split.r_valid ),
    .ready_o    ( axi_req_split.r_ready  ),
    // to fetcher
    .data_o     ( axi_resp_fetcher.r       ),
    .valid_o    ( axi_resp_fetcher.r_valid ),
    .ready_i    ( axi_req_fetcher.r_ready  )
  );

  // read is completed on valid and ready beat being popped from FIFO
  assign read_completed = axi_req_fetcher.r_ready & axi_resp_fetcher.r_valid;

  axi_burst_splitter_gran #(
      .MaxReadTxns   ( MaxReadTxns   ),
      .MaxWriteTxns  ( 32'd1         ), // technically 0, but not supported
      .FullBW        ( 1'b1          ),
      .CutPath       ( 1'b0          ),
      .DisableChecks ( 1'b0          ),
      .AddrWidth     ( AXIAddrWidth  ),
      .DataWidth     ( AXIDataWidth  ),
      .IdWidth       ( AXIIdWidth    ),
      .UserWidth     ( AXIUserWidth  ),

      .axi_req_t     ( axi_req_t     ),
      .axi_resp_t    ( axi_resp_t    ),
      .axi_aw_chan_t ( axi_aw_chan_t ),
      .axi_w_chan_t  ( axi_w_chan_t  ),
      .axi_b_chan_t  ( axi_b_chan_t  ),
      .axi_ar_chan_t ( axi_ar_chan_t ),
      .axi_r_chan_t  ( axi_r_chan_t  )
  ) i_axi_burst_splitter_gran (
      .clk_i,
      .rst_ni,
      .len_limit_i ( reg2hw.burst_split_len.q ),
      .slv_req_i   ( axi_req_split  ),
      .slv_resp_o  ( axi_resp_split ),
      .mst_req_o   ( axi_req        ),
      .mst_resp_i  ( axi_resp       )
  );

  // combine the read handshaking and the credit counter
  stream_join #(
    .N_INP ( 32'd2 )
  ) i_stream_join (
    .inp_valid_i ( {credit_valid, axi_req.ar_valid}     ), // free credits and valid request from splitter
    .inp_ready_o ( {credit_ready, axi_resp_cc_ar_ready} ),
    .oup_valid_o ( axi_req_cc_ar_valid                  ), // then outgoing request is valid
    .oup_ready_i ( axi_resp_i.ar_ready                  )  // distribute incoming ready to splitter and counter
  );

  always_comb begin
    axi_req_o = axi_req;
    axi_req_o.ar_valid = axi_req_cc_ar_valid;
    axi_resp = axi_resp_i;
    axi_resp.ar_ready = axi_resp_cc_ar_ready;
  end


  // tracks beats from splitter requests to response fifo being popped by fetcher
  always_comb begin : proc_credit_counter
    // default
    counter_d    = counter_q;
    credit_valid = 1'b0;

    // flush all in-flight data at the end of a frame (stale)
    if (frame_done_o) begin
      counter_d = counter_d - fifo_usage;
    end

    if (read_completed) begin
      counter_d = counter_d - 32'd1;
    end
    // does FIFO have enough space for requested number of beats?
    if (counter_d + (axi_req_o.ar.len + 1) <= BufferDepth) begin
      credit_valid = 1'b1;
      counter_d = credit_ready ? counter_d + (axi_req_o.ar.len + 1) : counter_d;
    end
  end

  // registers
  `FF(clk_cnt_q, clk_cnt_d, '0)
  `FF(counter_q, counter_d, '0)


  /////////////////////
  // Some assertions //
  /////////////////////

  // Ensure a pixel is always smaller than or equal to a word
  `ASSERT_INIT(AXI_fits_PixelWidth, (AXIDataWidth >= (RedWidth + GreenWidth + BlueWidth)))

  // Ensure the word width is a multiple of the pixel width
  `ASSERT_INIT(AXI_is_multiple_of_PixelWidth,
    (AXIDataWidth % (RedWidth + GreenWidth + BlueWidth)) == 0)

endmodule
