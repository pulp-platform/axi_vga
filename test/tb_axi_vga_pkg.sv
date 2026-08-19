// Copyright 2025 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Philippe Sauter <phsauter@iis.ee.ethz.ch>

package tb_axi_vga_pkg;
	localparam int unsigned FrameWidth  = 640; 
	localparam int unsigned FrameHeight = 480;

	localparam int unsigned RedWidth       = 5;
	localparam int unsigned GreenWidth     = 6;
	localparam int unsigned BlueWidth      = 5;
	localparam int unsigned PixelWidth     = 5+5+6;
	localparam int unsigned PixelByteWidth = PixelWidth/8;
	localparam int unsigned ColorDepth     = 8; // per-pixel color depth of BMP file

	typedef struct packed {
		logic enable;
		logic hsync_pol;
		logic vsync_pol;
	} control_cfg_t;

	typedef struct packed {
		control_cfg_t control;
		logic [31:0] clk_div;
		logic [31:0] hori_visible_size;
		logic [31:0] hori_front_porch_size;
		logic [31:0] hori_sync_size;
		logic [31:0] hori_back_porch_size;
		logic [31:0] vert_visible_size;
		logic [31:0] vert_front_porch_size;
		logic [31:0] vert_sync_size;
		logic [31:0] vert_back_porch_size;
		logic [31:0] start_addr_low;
		logic [31:0] start_addr_high;
		logic [31:0] frame_size;
		logic [31:0] burst_len;
		logic [31:0] burst_split_len;
	} vga_cfg_t;

	// config register values
	localparam vga_cfg_t cfg = '{
		control: 			   '{enable:    1'b0, hsync_pol: 1'b1, vsync_pol: 1'b1},
		clk_div:               32'h00000002, // 25MHz
		hori_visible_size:     FrameWidth,   // 640
		hori_front_porch_size: 32'h00000010, // per spec
		hori_sync_size:        32'h00000060,
		hori_back_porch_size:  32'h00000030,
		vert_visible_size:     FrameHeight,  // 480
		vert_front_porch_size: 32'h0000000A, // per spec
		vert_sync_size:        32'h00000002,
		vert_back_porch_size:  32'h00000021,
		start_addr_low:        32'h80001000,
		start_addr_high:       32'h00000000,
		frame_size:            32'(PixelByteWidth * FrameWidth * FrameHeight),
		burst_len:             32'h000000FF,
		burst_split_len:       32'h00000007
	};

	localparam int unsigned FullRenderWidth = (
		cfg.hori_visible_size +
		cfg.hori_front_porch_size +
		cfg.hori_sync_size +
		cfg.hori_back_porch_size
	);

	localparam int unsigned FullRenderHeight = (
		cfg.vert_visible_size +
		cfg.vert_front_porch_size +
		cfg.vert_sync_size +
		cfg.vert_back_porch_size
	);

	typedef struct packed {
		logic [RedWidth-1:0]   r;
		logic [GreenWidth-1:0] g;
		logic [BlueWidth-1:0]  b;
	} pixel_t;
			
endpackage