// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>

module tb_axi_vga;

  `include "axi/typedef.svh"
  `include "register_interface/assign.svh"
  `include "register_interface/typedef.svh"

  localparam int unsigned ClkPeriod = 5ns;

  // AXI parameters
  localparam int unsigned AXIAddrWidth  = 48;
  localparam int unsigned AXIDataWidth  = 64;
  localparam int unsigned AXIStrbWidth  =  8;
  localparam int unsigned AXIIdWidth    =  2;
  localparam int unsigned AXIUserWidth  =  1;

  // RegBus parameters
  localparam int unsigned RegBusAddrWidth = 48;
  localparam int unsigned RegBusDataWidth = 32;
  localparam int unsigned RegBusStrbWidth =  4;

  logic clk, rst_n;

  clk_rst_gen #(
    .ClkPeriod    ( ClkPeriod ),
    .RstClkCycles ( 5         )
  ) i_clk_rst (
    .clk_o  ( clk   ),
    .rst_no ( rst_n )
  );

  // AXI interface
  `AXI_TYPEDEF_ALL(axi_vga_tb, logic [AXIAddrWidth-1:0], logic [AXIIdWidth-1:0], logic [AXIDataWidth-1:0], logic [AXIStrbWidth-1:0], logic [AXIUserWidth-1:0])
  
  axi_vga_tb_req_t  vga_axi_req;
  axi_vga_tb_resp_t vga_axi_resp;

  // RegBus interface
  `REG_BUS_TYPEDEF_ALL(reg_vga_tb, logic [RegBusAddrWidth-1:0], logic [RegBusDataWidth-1:0], logic [RegBusStrbWidth-1:0])
  
  REG_BUS #(
      .ADDR_WIDTH ( RegBusAddrWidth  ),
      .DATA_WIDTH ( RegBusDataWidth  )
  ) i_tb_regbus (
      .clk_i  ( clk )
  );

  typedef reg_test::reg_driver #(
      .AW ( RegBusAddrWidth  ),
      .DW ( RegBusDataWidth  )
  ) reg_driver_t;

  reg_driver_t tb_reg_driver = new(i_tb_regbus);

  reg_vga_tb_req_t vga_reg_req;
  reg_vga_tb_rsp_t vga_reg_rsp;

  `REG_BUS_ASSIGN_TO_REQ(vga_reg_req, i_tb_regbus)
  `REG_BUS_ASSIGN_FROM_RSP(i_tb_regbus, vga_reg_rsp)

  logic bus_error;
    
  // Initiate VGA driver - 32x16 testing mode
  initial begin
    #(10 * ClkPeriod);
    tb_reg_driver.reset_master();

    // Clock divider
    tb_reg_driver.send_write(48'h4, 32'h8, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Horizontal visible portion
    tb_reg_driver.send_write(48'h8, 32'h21, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Horizontal front porch
    tb_reg_driver.send_write(48'hC, 32'h3, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Horizontal sync part
    tb_reg_driver.send_write(48'h10, 32'h5, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Horizontal back porch
    tb_reg_driver.send_write(48'h14, 32'h4, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Vertical visible portion
    tb_reg_driver.send_write(48'h18, 32'h20, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Vertical front porch
    tb_reg_driver.send_write(48'h1C, 32'h3, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Vertical sync part
    tb_reg_driver.send_write(48'h20, 32'h5, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Vertical back porch
    tb_reg_driver.send_write(48'h24, 32'h4, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Frame size in byte
    // 33x32x2 = 0x840
    tb_reg_driver.send_write(48'h30, 32'h840, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Low end of start address of frame buffer
    tb_reg_driver.send_write(48'h28, 32'h800007F0, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");
    // High end of start address of frame buffer
    tb_reg_driver.send_write(48'h2c, 32'h0, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Burst length
    tb_reg_driver.send_write(48'h34, 32'hff, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // FSM enable
    tb_reg_driver.send_write(48'h0, 32'h1, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

  end

  // Initiate VGA driver
  /*initial begin
    #(10 * ClkPeriod);
    tb_reg_driver.reset_master();

    // Clock divider
    tb_reg_driver.send_write(48'h4, 32'h2, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Horizontal visible portion
    tb_reg_driver.send_write(48'h8, 32'h280, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Horizontal front porch
    tb_reg_driver.send_write(48'hC, 32'h10, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Horizontal sync part
    tb_reg_driver.send_write(48'h10, 32'h60, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Horizontal back porch
    tb_reg_driver.send_write(48'h14, 32'h30, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Vertical visible portion
    tb_reg_driver.send_write(48'h18, 32'h1e0, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Vertical front porch
    tb_reg_driver.send_write(48'h1C, 32'hA, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Vertical sync part
    tb_reg_driver.send_write(48'h20, 32'h2, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Vertical back porch
    tb_reg_driver.send_write(48'h24, 32'h21, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Frame size in byte
    // 640x350xX Byte per Pixel: h6d600
    // 1b00 - 3 full REQ, 1 smaller, 6912 Byte
    tb_reg_driver.send_write(48'h30, 32'h96000, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Low end of start address of frame buffer
    tb_reg_driver.send_write(48'h28, 32'h80000000, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");
    // High end of start address of frame buffer
    tb_reg_driver.send_write(48'h2c, 32'h0, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // Burst length
    tb_reg_driver.send_write(48'h34, 32'hff, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    // FSM enable
    tb_reg_driver.send_write(48'h0, 32'h1, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    #(5000 * ClkPeriod);

    // FSM enable
    tb_reg_driver.send_write(48'h0, 32'h0, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

    #(5000 * ClkPeriod);

    // FSM enable
    tb_reg_driver.send_write(48'h0, 32'h1, 4'hf, bus_error);
    assert (!bus_error) else $error("Not able to write cfg reg");

  end*/

  axi_sim_mem #(
    /// AXI Address Width
    .AddrWidth          ( AXIAddrWidth      ),
    /// AXI Data Width
    .DataWidth          ( AXIDataWidth      ),
    /// AXI ID Width 
    .IdWidth            ( AXIIdWidth        ),
    /// AXI User Width.
    .UserWidth          ( AXIUserWidth      ),
    /// AXI4 request struct definition
    .axi_req_t          ( axi_vga_tb_req_t  ),
    /// AXI4 response struct definition
    .axi_rsp_t          ( axi_vga_tb_resp_t ),
    /// Warn on accesses to uninitialized bytes
    .WarnUninitialized  ( 1                 ),
    /// Application delay (measured after rising clock edge)
    .ApplDelay          ( 2ns               ),
    /// Acquisition delay (measured after rising clock edge)
    .AcqDelay           ( 1ns               )
  ) i_axi_sim_mem (
    /// Rising-edge clock
    .clk_i              ( clk           ),
    /// Active-low reset
    .rst_ni             ( rst_n         ),
    /// AXI4 request struct
    .axi_req_i          ( vga_axi_req   ),
    /// AXI4 response struct
    .axi_rsp_o          ( vga_axi_resp  ),
    /// Memory monitor write valid.  All `mon_w_*` outputs are only valid if this signal is high.
    /// A write to the memory is visible on the `mon_w_*` outputs in the clock cycle after it has
    /// happened.
    .mon_w_valid_o      (               ),
    /// Memory monitor write address
    .mon_w_addr_o       (               ),
    /// Memory monitor write data
    .mon_w_data_o       (               ),
    /// Memory monitor write ID
    .mon_w_id_o         (               ),
    /// Memory monitor write user
    .mon_w_user_o       (               ),
    /// Memory monitor write beat count
    .mon_w_beat_count_o (               ),
    /// Memory monitor write last
    .mon_w_last_o       (               ),
    /// Memory monitor read valid.  All `mon_r_*` outputs are only valid if this signal is high.
    /// A read from the memory is visible on the `mon_w_*` outputs in the clock cycle after it has
    /// happened.
    .mon_r_valid_o      (               ),
    /// Memory monitor read address
    .mon_r_addr_o       (               ),
    /// Memory monitor read data
    .mon_r_data_o       (               ),
    /// Memory monitor read ID
    .mon_r_id_o         (               ),
    /// Memory monitor read user
    .mon_r_user_o       (               ),
    /// Memory monitor read beat count
    .mon_r_beat_count_o (               ),
    /// Memory monitor read last
    .mon_r_last_o       (               )
  );

  initial begin
      $readmemh("../test/count.mem", i_axi_sim_mem.mem);
  end

  axi_vga #(
    .RedWidth       ( 5                 ),
    .GreenWidth     ( 6                 ),
    .BlueWidth      ( 5                 ),
    .HCountWidth    ( 12                ),
    .VCountWidth    ( 12                ),
    .AXIAddrWidth   ( AXIAddrWidth      ),
    .AXIDataWidth   ( AXIDataWidth      ),
    .AXIStrbWidth   ( AXIStrbWidth      ),
    .axi_req_t      ( axi_vga_tb_req_t  ),
    .axi_resp_t     ( axi_vga_tb_resp_t ),
    .reg_req_t      ( reg_vga_tb_req_t  ),
    .reg_resp_t     ( reg_vga_tb_rsp_t  )
  ) i_axi_vga (
    .clk_i          ( clk           ),
    .rst_ni         ( rst_n         ),

    .test_mode_en_i ( 1'b0          ),

    // Regbus config ports
    .reg_req_i      ( vga_reg_req   ),
    .reg_rsp_o      ( vga_reg_rsp   ),

    // AXI Data ports
    .axi_req_o      ( vga_axi_req   ),
    .axi_resp_i     ( vga_axi_resp  ),

    // VGA interface
    .hsync_o        (               ),
    .vsync_o        (               ),
    .red_o          (               ),
    .green_o        (               ),
    .blue_o         (               )
  );


endmodule
