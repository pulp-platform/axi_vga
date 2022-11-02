// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>

// Simple VGA IP capable of drawing frames from an external framebuffer

module axi_vga #(
  parameter int unsigned RedWidth     = 5,
  parameter int unsigned GreenWidth   = 6,
  parameter int unsigned BlueWidth    = 5,
  parameter int unsigned HCountWidth  = 32,
  parameter int unsigned VCountWidth  = 32,
  parameter int unsigned AXIAddrWidth = 64,
  parameter int unsigned AXIDataWidth = 64,
  parameter int unsigned AXIStrbWidth = 8,
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

  // VGA interface
  output logic                    hsync_o,
  output logic                    vsync_o,
  output logic [RedWidth-1:0]     red_o,
  output logic [GreenWidth-1:0]   green_o,
  output logic [BlueWidth-1:0]    blue_o
);
    
  logic [7:0] clk_div;
  logic [7:0] clk_cycle_count;
  axi_vga_register_file_reg_pkg::axi_vga_register_file_reg2hw_t reg2hw;

  logic [RedWidth-1:0]   red;
  logic [GreenWidth-1:0] green;
  logic [BlueWidth-1:0]  blue;
  logic valid, ready;

  // Clock divider constant
  assign clk_div = reg2hw.clk_div.q;

  // Clock divider to get the pixel clock
  clk_int_div #(
    .DIV_VALUE_WIDTH       ( 8              ),
    .DEFAULT_DIV_VALUE     ( 8              ),
    .ENABLE_CLOCK_IN_RESET ( 1'b0           )
  ) i_pixel_clk_div (
    .clk_i,
    .rst_ni,

    .en_i             ( 1'b1                ),

    .test_mode_en_i,

    .div_i            ( clk_div             ),

    .div_valid_i      ( 1'b1                ),
    .div_ready_o      (                     ),

    .clk_o            (                     ),

    .cycl_count_o     ( clk_cycle_count     )
  );

  // Regbus register interface
  axi_vga_register_file_reg_top #(
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
      .devmode_i      ( '0                  )  // If 1, explicit error return for unmapped register access
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

      .fsm_en_i       ( clk_cycle_count == 0),
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

      .axi_req_o,
      .axi_resp_i,

      .start_addr_i   ( {reg2hw.start_addr_high.q, reg2hw.start_addr_low.q}),
      .frame_size_i   ( reg2hw.frame_size.q ),
      .burst_len_i    ( reg2hw.burst_len.q  ),
      .red_o          ( red                 ),
      .green_o        ( green               ),
      .blue_o         ( blue                ),
      .valid_o        ( valid               ),
      .ready_i        ( ready               )
  );


   /////////////////////
   // Some assertions //
   /////////////////////

   // Ensure a pixel is always smaller than or equal to a word
   assert property (@(posedge clk_i) AXIDataWidth >= (RedWidth + GreenWidth + BlueWidth)) else begin
      $error("AXIDataWidth has to be larger than or equal to the pixel width");
      $stop();
   end

   // Ensure the word width is a multiple of the pixel width
   assert property (@(posedge clk_i) (AXIDataWidth % (RedWidth + GreenWidth + BlueWidth)) == 0) else begin
      $error("AXIDataWidth has to be a multiple of the pixel width");
      $stop();
   end

endmodule
