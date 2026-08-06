// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>

`include "axi/typedef.svh"
`include "apb/typedef.svh"

module tb_axi_vga;
	import axi_vga_reg_pkg::*;
	import axi_vga_reg_offsets_pkg::*;
	import tb_axi_vga_pkg::*;

	localparam int unsigned ClkPeriod = 20ns;
	localparam int unsigned NumFramesToCapture = 1;

	// AXI parameters
	localparam int unsigned AXIAddrWidth  = 48;
	localparam int unsigned AXIDataWidth  = 64;
	localparam int unsigned AXIStrbWidth  =  8;
	localparam int unsigned AXIIdWidth    =  2;
	localparam int unsigned AXIUserWidth  =  1;

	// Buffer
	localparam int unsigned BufferDepth = 16;
	localparam int unsigned MaxReadTxns = 24;
	// Mem Depth
	localparam int unsigned MemDepth = 32;

	// APB parameters
	localparam int unsigned APBAddrWidth = 32;
	localparam int unsigned APBDataWidth = 32;

	typedef logic [APBAddrWidth-1:0]   apb_addr_t;
	typedef logic [APBDataWidth-1:0]   apb_data_t;
	typedef logic [APBDataWidth/8-1:0] apb_strb_t;

	`APB_TYPEDEF_REQ_T(apb_req_t, apb_addr_t, apb_data_t, apb_strb_t)
	`APB_TYPEDEF_RESP_T(apb_resp_t, apb_data_t)

	apb_req_t  vga_apb_req;
    apb_resp_t vga_apb_rsp;

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

	axi_vga_tb_req_t  vga_axi_req, vga_axi_req_dly;
	axi_vga_tb_resp_t vga_axi_resp, vga_axi_resp_dly;


	APB_DV #(
		.ADDR_WIDTH ( APBAddrWidth ),
		.DATA_WIDTH ( APBDataWidth )
	) i_tb_apb (
		.clk_i ( clk )
	);

	typedef apb_test::apb_driver #(
		.ADDR_WIDTH ( APBAddrWidth ),
		.DATA_WIDTH ( APBDataWidth )
	) apb_driver_t;

	apb_driver_t tb_apb_driver = new(i_tb_apb);

	assign vga_apb_req.paddr   = i_tb_apb.paddr;
    assign vga_apb_req.pprot   = i_tb_apb.pprot;
    assign vga_apb_req.psel    = i_tb_apb.psel;
    assign vga_apb_req.penable = i_tb_apb.penable;
    assign vga_apb_req.pwrite  = i_tb_apb.pwrite;
    assign vga_apb_req.pwdata  = i_tb_apb.pwdata;
    assign vga_apb_req.pstrb   = i_tb_apb.pstrb;

    assign i_tb_apb.pready  = vga_apb_rsp.pready;
    assign i_tb_apb.prdata  = vga_apb_rsp.prdata;
    assign i_tb_apb.pslverr = vga_apb_rsp.pslverr;

	typedef struct {
		logic [APBAddrWidth-1:0] addr;
		logic [APBDataWidth-1:0] data;
		string desc;
	} reg_write_t;

	logic bus_error = 0;

	// Initiate VGA driver - 32x16 testing mode
	initial begin
		automatic reg_write_t writes [] = '{
			'{AXI_VGA_CLK_DIV_OFFSET,               cfg.clk_div,               "Clock divider"},
			'{AXI_VGA_HORI_VISIBLE_SIZE_OFFSET,     cfg.hori_visible_size,     "Horizontal visible frame size"},
			'{AXI_VGA_HORI_FRONT_PORCH_SIZE_OFFSET, cfg.hori_front_porch_size, "Horizontal front porch"},
			'{AXI_VGA_HORI_SYNC_SIZE_OFFSET,        cfg.hori_sync_size,        "Horizontal sync part"},
			'{AXI_VGA_HORI_BACK_PORCH_SIZE_OFFSET,  cfg.hori_back_porch_size,  "Horizontal back porch"},
			'{AXI_VGA_VERT_VISIBLE_SIZE_OFFSET,     cfg.vert_visible_size,     "Vertical visible frame size"},
			'{AXI_VGA_VERT_FRONT_PORCH_SIZE_OFFSET, cfg.vert_front_porch_size, "Vertical front porch"},
			'{AXI_VGA_VERT_SYNC_SIZE_OFFSET,        cfg.vert_sync_size,        "Vertical sync part"},
			'{AXI_VGA_VERT_BACK_PORCH_SIZE_OFFSET,  cfg.vert_back_porch_size,  "Vertical back porch"},
			'{AXI_VGA_START_ADDR_LOW_OFFSET,        cfg.start_addr_low,        "Low end of frame buffer"},
			'{AXI_VGA_START_ADDR_HIGH_OFFSET,       cfg.start_addr_high,       "High end of frame buffer"},
			'{AXI_VGA_FRAME_SIZE_OFFSET,            cfg.frame_size,            "Frame size (#pixels)"},
			'{AXI_VGA_BURST_LEN_OFFSET,             cfg.burst_len,             "Prefetch burst length"},
			'{AXI_VGA_BURST_SPLIT_LEN_OFFSET,       cfg.burst_split_len,       "AXI burst length"}
		};

		#(10 * ClkPeriod);
		tb_apb_driver.reset_master();
		#(10 * ClkPeriod);

		for (int i = 0; i < writes.size(); i++) begin
			$info("TEST: %s", writes[i].desc);
			tb_apb_driver.write(writes[i].addr, writes[i].data, 4'hF, bus_error);
			assert (!bus_error) else $fatal("Write to VGA cfg reg (0x%0h) failed", writes[i].addr);
		end

		$info("TEST: FSM enable");
		tb_apb_driver.write(AXI_VGA_CONTROL_OFFSET, 32'h1, 4'hF, bus_error);
		assert (!bus_error) else $fatal("Write to VGA cfg reg (0x%0h) failed", AXI_VGA_CONTROL_OFFSET);

		$info("TEST: Render");
		// See frame capture bock below
		#(20*ClkPeriod * cfg.clk_div * FullRenderHeight * FullRenderWidth);
		#(5000 * ClkPeriod);
		$info("TIMEOUT");
		$finish();
	end


	pixel_t framebuffer [FrameHeight][FrameWidth];

	task write_frame_to_bmp(string file);
		automatic int fd, fd_debug;
		automatic int i, j;
		automatic byte r8, g8, b8;
		automatic int row_pad = (4 - (FrameWidth * 3) % 4) % 4;
		automatic int filesize = 54 + (FrameWidth * 3 + row_pad) * FrameHeight;

		fd = $fopen(file, "wb");
		fd_debug = $fopen("bmp_write_dump.txt", "w");

		// bitmap header (14 bytes)
		$fwrite(fd, "%c%c", "B", "M");                      // signature (fixed)
		$fwrite(fd, "%u", filesize);                        // file size (#bytes)
		$fwrite(fd, "%u", 0);                               // reserved
		$fwrite(fd, "%u", 54);                              // data offset

		// DIP header (BITMAPINFOHEADER)
		$fwrite(fd, "%u", 40);                              // header size
		$fwrite(fd, "%u", FrameWidth);                      // img width (#pixels)
		$fwrite(fd, "%u", FrameHeight);                     // img height (#pixels)
		$fwrite(fd, "%u", 32'h00_18_00_01); // #planes (must be 1), #bits per pixel (24)
		$fwrite(fd, "%u", 0);                               // compression (no)
		$fwrite(fd, "%u", (FrameWidth * 3 + row_pad) * FrameHeight); // image size
		$fwrite(fd, "%u", 1000);                            // X pixels/meter
		$fwrite(fd, "%u", 1000);                            // Y pixels/meter
		$fwrite(fd, "%u", 0);                               // colors used
		$fwrite(fd, "%u", 0);                               // important colors

		// Pixels (format:BGR, frame bottom-up)
		for (i = FrameHeight-1; i >= 0; i--) begin
			for (j = 0; j < FrameWidth; j++) begin
				r8 = framebuffer[i][j].r << (8 - RedWidth);
				g8 = framebuffer[i][j].g << (8 - GreenWidth);
				b8 = framebuffer[i][j].b << (8 - BlueWidth);
				$fwrite(fd, "%c%c%c", b8, g8, r8);
				$fwrite(fd_debug, "(row=%0d, col=%0d): R=%0d, G=%0d, B=%0d\n", FrameHeight - 1 - i, j, r8, g8, b8);
			end
			for (j = 0; j < row_pad; j++)
				$fwrite(fd, "%c", 8'h00);
		end

		$fclose(fd_debug);
		$fclose(fd);
	endtask


	initial begin : frame_capture
		automatic int clk_div_counter = 0;
		automatic int hsync_porch = 0, vsync_porch = 0;
		automatic bit hsync_prev = 0,  vsync_prev = 0;
		automatic int row = 0, col = 0;
		automatic int frame_num = 0;
		automatic bit capturing = 0;
		automatic string file;

		wait (rst_n === 0);
		@(posedge rst_n);
		@(negedge i_axi_vga.vsync_o); // sync capturing on first vsync
		forever begin
			// before the divided clock, capture the previous values
			if (clk_div_counter == '0) begin
				hsync_prev = i_axi_vga.hsync_o;
				vsync_prev = i_axi_vga.vsync_o;
			end

			@(posedge clk);
			#(0.8 * ClkPeriod);

			// clock divider: skip rest except every N-th clock edge
			clk_div_counter++;
			if (clk_div_counter < cfg.clk_div) begin
				continue;
			end else begin
				clk_div_counter = 0;
			end

			// start capturing frame after vsync pulse
			if (vsync_prev == cfg.control.vsync_pol &&
			    i_axi_vga.vsync_o == ~cfg.control.vsync_pol) begin
				vsync_porch = 0;
				hsync_porch = 0;
				row = 0;
				col = 0;
				capturing = 1;
				$info("VSYNC PULSE: Start capturing frame");
				continue;
			end

			// skip vertical back porch
			if (capturing && vsync_porch < cfg.vert_back_porch_size) begin
				if (hsync_prev == cfg.control.hsync_pol &&
				    i_axi_vga.hsync_o == ~cfg.control.hsync_pol) begin
					vsync_porch++;
				end
				continue;
			end


			// capture lines with visible area
			if (capturing && row < FrameHeight) begin
				// start capturing current line after hsync pulse
				if (hsync_prev == cfg.control.hsync_pol &&
				    i_axi_vga.hsync_o == ~cfg.control.hsync_pol) begin
					hsync_porch = 0;
					col = 0;
					row++;
					$info("Capturing line no #%0d", row);
					continue;
				end

				// skip horizontal back porch
				if (hsync_porch < (cfg.hori_back_porch_size-1)) begin
					hsync_porch++;
					continue;
				end 

				// capture pixel in visible area of this line
				if (col < FrameWidth) begin
					framebuffer[row][col].r = i_axi_vga.red_o;
					framebuffer[row][col].g = i_axi_vga.green_o;
					framebuffer[row][col].b = i_axi_vga.blue_o;
					col++;
				end
			end

			// if (capturing && row == FrameHeight) begin
			// 	file = $sformatf("frame_%0d.bmp", frame_num++);
			// 	write_frame_to_bmp(file);
			// 	$info("Frame #%0d captured to %s", frame_num-1, file);
			// 	capturing = 0;
			// end

			//Capturing only one frame
			//
			if (capturing && row == FrameHeight) begin
				file = $sformatf("frame_%0d.bmp", frame_num++);
				write_frame_to_bmp(file);
				$info("Frame #%0d captured to %s", frame_num-1, file);
				capturing = 0;

				if (frame_num == NumFramesToCapture) begin
					$info("Captured %0d frame(s). Finishing simulation.", NumFramesToCapture);
					$finish();
				end
			end
		end
	end


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
		.ApplDelay          ( (ClkPeriod*0.3)   ),
		/// Acquisition delay (measured after rising clock edge)
		.AcqDelay           ( (ClkPeriod*0.8)   )
	) i_axi_sim_mem (
		/// Rising-edge clock
		.clk_i              ( clk              ),
		/// Active-low reset
		.rst_ni             ( rst_n            ),
		/// AXI4 request struct
		.axi_req_i          ( vga_axi_req_dly  ),
		/// AXI4 response struct
		.axi_rsp_o          ( vga_axi_resp_dly ),
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


	task read_bmp(input string file);
		automatic int fd, fd_debug;
		automatic int i, j, k;
		automatic int data_offset;
		automatic int width, height;
		automatic int tmp;

		automatic int row_size_bytes, padding;

		automatic byte r8, g8, b8;
		automatic pixel_t pixel;
		automatic int dst_pixel_index = 0;
		automatic int start_addr = (cfg.start_addr_high << 32) | cfg.start_addr_low;
		fd_debug = $fopen("bmp_read_dump.txt", "w");

		fd = $fopen(file, "rb");
		if (fd == 0) begin
			$display("[ERROR] Cannot open file: %s", file);
			$finish;
		end

		// skip signature
		tmp = $fgetc(fd); // 'B'
		tmp = $fgetc(fd); // 'M'

		// filesize
		tmp = $fgetc(fd); tmp |= $fgetc(fd) << 8; tmp |= $fgetc(fd) << 16; tmp |= $fgetc(fd) << 24;
		tmp = $fgetc(fd); tmp = $fgetc(fd); tmp = $fgetc(fd); tmp = $fgetc(fd); // reserved
		data_offset = 0; // data offset
		data_offset |= $fgetc(fd); data_offset |= $fgetc(fd) << 8;
		data_offset |= $fgetc(fd) << 16; data_offset |= $fgetc(fd) << 24;

		// DIB header
		tmp = $fgetc(fd); tmp = $fgetc(fd); tmp = $fgetc(fd); tmp = $fgetc(fd); // header size

		// image width
		width = $fgetc(fd); width |= $fgetc(fd) << 8;
		width |= $fgetc(fd) << 16; width |= $fgetc(fd) << 24;

		// image height
		height = $fgetc(fd); height |= $fgetc(fd) << 8;
		height |= $fgetc(fd) << 16; height |= $fgetc(fd) << 24;
		if (height != FrameHeight || width != FrameWidth) begin
			$error("Bitmap has wrong dimensions (is %0dx%0d, should %0dx%0dx)", width, height, FrameWidth, FrameHeight);
		end

		tmp = $fgetc(fd); tmp = $fgetc(fd); // planes
		tmp = $fgetc(fd); tmp = $fgetc(fd); // bpp (assumes 24bit)

		// skip compression, image size, resolution...
		repeat (24) tmp = $fgetc(fd);

		// go to pixel data
		while ($ftell(fd) < data_offset) tmp = $fgetc(fd);

		// rows are padded to a 4-byte alignment
		row_size_bytes = ((width * 3 + 3) / 4) * 4;
		padding = row_size_bytes - width * 3;

		// read pixel data (format: BGR, bottom-up)
		for (i = height - 1; i >= 0; i--) begin
			for (j = 0; j < width; j++) begin
				b8 = $fgetc(fd);
				g8 = $fgetc(fd);
				r8 = $fgetc(fd);

				pixel.b = b8 >> (8 - BlueWidth);
				pixel.g = g8 >> (8 - GreenWidth);
				pixel.r = r8 >> (8 - RedWidth);

				$fwrite(fd_debug, "(row=%0d, col=%0d): R=%0d, G=%0d, B=%0d\n", i, j, r8, g8, b8);

				// convert BMP bottom-up row index to top-down memory index
				// ASSUMPTION: RGB together pack into a multiple of a byte
				dst_pixel_index = i * FrameWidth + j;
				for (k = 0; k < PixelByteWidth; k++) begin
					i_axi_sim_mem.mem[start_addr + dst_pixel_index*PixelByteWidth + k] = pixel;
					pixel = pixel >> 8;
				end
			end
			// skip padding
			repeat (padding) tmp = $fgetc(fd);
		end

		$fclose(fd);
		$fclose(fd_debug);
	endtask

	initial begin
		$readmemh("../test/count.mem", i_axi_sim_mem.mem);
		//read_bmp("../test/increment.bmp");
	end

	axi_multicut #(
		.NoCuts     ( MemDepth             ),
		.aw_chan_t  ( axi_vga_tb_aw_chan_t ),
		.w_chan_t   ( axi_vga_tb_w_chan_t  ),
		.b_chan_t   ( axi_vga_tb_b_chan_t  ),
		.ar_chan_t  ( axi_vga_tb_ar_chan_t ),
		.r_chan_t   ( axi_vga_tb_r_chan_t  ),
		.axi_req_t  ( axi_vga_tb_req_t     ),
		.axi_resp_t ( axi_vga_tb_resp_t    )
	) i_axi_multicut (
		.clk_i      ( clk              ),
		.rst_ni     ( rst_n            ),
		.slv_req_i  ( vga_axi_req      ),
		.slv_resp_o ( vga_axi_resp     ),
		.mst_req_o  ( vga_axi_req_dly  ),
		.mst_resp_i ( vga_axi_resp_dly )
	);


	axi_vga #(
		.RedWidth       ( RedWidth            ),
		.GreenWidth     ( GreenWidth          ),
		.BlueWidth      ( BlueWidth           ),
		.HCountWidth    ( 12                  ),
		.VCountWidth    ( 12                  ),
		.AXIAddrWidth   ( AXIAddrWidth        ),
		.AXIDataWidth   ( AXIDataWidth        ),
		.AXIStrbWidth   ( AXIStrbWidth        ),
		.AXIIdWidth     ( AXIIdWidth          ),
		.AXIUserWidth   ( AXIUserWidth        ),
		.BufferDepth    ( BufferDepth         ),
		.MaxReadTxns    ( MaxReadTxns         ),
		.axi_req_t      ( axi_vga_tb_req_t    ),
		.axi_resp_t     ( axi_vga_tb_resp_t   ),
		.axi_r_chan_t   ( axi_vga_tb_r_chan_t ),

        .apb_req_t      ( apb_req_t           ),
        .apb_resp_t     ( apb_resp_t          )
	) i_axi_vga (
		.clk_i          ( clk           ),
		.rst_ni         ( rst_n         ),

		.test_mode_en_i ( 1'b0          ),

        // APB config interface
        .apb_req_i      ( vga_apb_req  ),
        .apb_rsp_o      ( vga_apb_rsp  ),

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
