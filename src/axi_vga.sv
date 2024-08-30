// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>
// Thomas Benz <tbenz@iis.ee.ethz.ch>

`include "common_cells/assertions.svh"
`include "common_cells/registers.svh"

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
  parameter int unsigned BufferDepth  = 16,
  parameter int unsigned MaxReadTxns  = 24,
  parameter type axi_req_t            = logic,
  parameter type axi_resp_t           = logic,
  parameter type axi_r_chan_t         = logic,
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

  // VGA interface
  output logic                    hsync_o,
  output logic                    vsync_o,
  output logic [RedWidth-1:0]     red_o,
  output logic [GreenWidth-1:0]   green_o,
  output logic [BlueWidth-1:0]    blue_o
);

  /// credit counter width
  localparam int unsigned CounterWidth = $clog2(BufferDepth + 32'd1);
  /// credit counter type
  typedef logic[CounterWidth-1:0] counter_t;

  logic [7:0] clk_div;
  logic [7:0] clk_cnt_d, clk_cnt_q;

  axi_vga_reg_pkg::axi_vga_reg2hw_t reg2hw;

  axi_req_t  axi_req,  axi_req_split;
  axi_resp_t axi_resp, axi_resp_split;

  logic     read_completed;
  logic     credit_valid;
  logic     credit_ready;
  counter_t counter_d, counter_q;

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
    .enable_i       ( reg2hw.control.enable.q),

    .axi_req_o      ( axi_req             ),
    .axi_resp_i     ( axi_resp            ),

    .start_addr_i   ( {reg2hw.start_addr_high.q, reg2hw.start_addr_low.q}),
    .frame_size_i   ( reg2hw.frame_size.q ),
    .burst_len_i    ( reg2hw.burst_len.q  ),
    .red_o          ( red                 ),
    .green_o        ( green               ),
    .blue_o         ( blue                ),
    .valid_o        ( valid               ),
    .ready_i        ( ready               )
  );

  axi_burst_splitter #(
      .MaxReadTxns  ( MaxReadTxns   ),
      .MaxWriteTxns ( 32'd1         ), // technically 0, but not supported
      .FullBW       ( 1'b1          ),
      .AddrWidth    ( AXIAddrWidth  ),
      .DataWidth    ( AXIDataWidth  ),
      .IdWidth      ( AXIIdWidth    ),
      .UserWidth    ( AXIUserWidth  ),
      .axi_req_t    ( axi_req_t     ),
      .axi_resp_t   ( axi_resp_t    )
  ) i_axi_burst_splitter (
      .clk_i,
      .rst_ni,
      .slv_req_i  ( axi_req        ),
      .slv_resp_o ( axi_resp       ),
      .mst_req_o  ( axi_req_split  ),
      .mst_resp_i ( axi_resp_split )
  );

  // Add stream FIFO in the response path to buffer requested data
  // rest of the response is just passed through
  // modulate number of outstanding AR's
  // request pass through
  assign axi_req_o.aw       = axi_req_split.aw;
  assign axi_req_o.aw_valid = axi_req_split.aw_valid;
  assign axi_req_o.w        = axi_req_split.w;
  assign axi_req_o.w_valid  = axi_req_split.w_valid;
  assign axi_req_o.b_ready  = axi_req_split.b_ready;
  assign axi_req_o.ar       = axi_req_split.ar;
  // response pass through
  assign axi_resp_split.aw_ready = axi_resp_i.aw_ready;
  assign axi_resp_split.w_ready  = axi_resp_i.w_ready;
  assign axi_resp_split.b_valid  = axi_resp_i.b_valid;
  assign axi_resp_split.b        = axi_resp_i.b;

  stream_fifo #(
    .FALL_THROUGH ( 32'd0               ),
    .DEPTH        ( BufferDepth + 32'd1 ), // +1 as the FIFO cannot be pushed and popped in-cycle
    .T            ( axi_r_chan_t        )
  ) i_stream_fifo (
    .clk_i,
    .rst_ni,
    .flush_i    ( 1'b0                   ),
    .testmode_i ( test_mode_en_i         ),
    .usage_o    ( /*NC*/                 ),
    .data_i     ( axi_resp_i.r           ),
    .valid_i    ( axi_resp_i.r_valid     ),
    .ready_o    ( axi_req_o.r_ready      ),
    .data_o     ( axi_resp_split.r       ),
    .valid_o    ( axi_resp_split.r_valid ),
    .ready_i    ( axi_req_split.r_ready  )
  );

  // combine the read handshaking and the credit counter
  stream_join #(
    .N_INP ( 32'd2 )
  ) i_stream_join (
    .inp_valid_i ( {credit_valid, axi_req_split.ar_valid } ),
    .inp_ready_o ( {credit_ready, axi_resp_split.ar_ready} ),
    .oup_valid_o ( axi_req_o.ar_valid                      ),
    .oup_ready_i ( axi_resp_i.ar_ready                     )
  );

  // read is completed on valid and ready r.last being popped from FIFO
  assign read_completed = axi_resp_split.r.last & axi_req_split.r_ready & axi_resp_split.r_valid;

  // simple credit counter
  always_comb begin : proc_credit_counter
    // default
    counter_d    = counter_q;
    credit_valid = 1'b0;
    // completed
    if (read_completed) begin
      counter_d = counter_d - 32'd1;
    end
    // possible issue?
    if (counter_d < BufferDepth) begin
      credit_valid = 1'b1;
      counter_d = credit_ready ? counter_d + 32'd1 : counter_d;
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
