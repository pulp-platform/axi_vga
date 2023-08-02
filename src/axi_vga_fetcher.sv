// Copyright 2022 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Nicole Narr <narrn@student.ethz.ch>
// Christopher Reinwardt <creinwar@student.ethz.ch>

// takes X byte burst and splits it into pixels to hand over to the vga timing fsm
// TODO: do pixel length modularly

module axi_vga_fetcher #(
  parameter int unsigned RedWidth     = 5,
  parameter int unsigned GreenWidth   = 6,
  parameter int unsigned BlueWidth    = 5,
  parameter int unsigned AXIAddrWidth = 64,
  parameter int unsigned AXIDataWidth = 64,
  parameter int unsigned AXIStrbWidth = 8,
  parameter type axi_req_t            = logic,
  parameter type axi_resp_t           = logic,
  localparam int unsigned AXIStrbWidthClog2 = $clog2(AXIStrbWidth)
)(
  input logic                     clk_i,
  input logic                     rst_ni,
  input logic                     enable_i,

  output axi_req_t                axi_req_o,
  input  axi_resp_t               axi_resp_i,

  // VGA interface
  input  logic [63:0]             start_addr_i,
  input  logic [31:0]             frame_size_i,
  input  logic [7:0]              burst_len_i,
  output logic [RedWidth-1:0]     red_o,
  output logic [GreenWidth-1:0]   green_o,
  output logic [BlueWidth-1:0]    blue_o,
  output logic                    valid_o,
  input  logic                    ready_i
);

  localparam int unsigned PixelWidth = RedWidth + GreenWidth + BlueWidth;
  logic [15:0] offset_q, offset_d;

  typedef enum logic       {R_IDLE, REQ} req_state_t;
  typedef enum logic       {ACCEPT, A_IDLE} accept_state_t;

  req_state_t req_state_q, req_state_d;
  accept_state_t accept_state_q, accept_state_d;

  axi_req_t axi_req;
  axi_resp_t axi_resp;

  logic [AXIAddrWidth-1:0] addr_page_mask, start_addr;
  logic [AXIAddrWidth-1:0] req_addr_q, req_addr_d;
  logic [AXIDataWidth-1:0] new_beat_data_q, new_beat_data_d;
  logic [AXIDataWidth-1:0] old_beat_data_q, old_beat_data_d;

  logic [AXIAddrWidth-1:0] frame_start_q, frame_start_d;
  logic [31:0] frame_size_q, frame_size_d, remaining_len;
  logic [7:0]  burst_len_q, burst_len_d, last_len_d, last_len_q;

  logic resp_last_q;

  logic first_req_q, first_req_d;
  logic init_done_q, init_done_d;
  logic process_started_q, process_started_d, process_started_last;
  logic valid_q, valid_d;

  assign valid_o = valid_q;

  assign axi_req_o = axi_req;
  assign axi_resp = axi_resp_i;

  assign axi_req.aw = '0;
  assign axi_req.aw_valid = '0;
  assign axi_req.w = '0;
  assign axi_req.w_valid = '0;
  assign axi_req.b_ready = '0;

  // Truncate or extend the fixed 64 bit we get from the regfile to the actual address width
  localparam int ZeroRepl = (AXIAddrWidth > 64) ? AXIAddrWidth - 64 : 0;
  assign start_addr = (AXIAddrWidth <= 64) ?
      start_addr_i[AXIAddrWidth-1:0] : {{ZeroRepl{1'b0}}, start_addr_i};

  // Create an AXIAddrWidth wide mask to ignore the lower 12 bit
  localparam int PageRemainingBits = AXIAddrWidth - 12;
  assign addr_page_mask = {{PageRemainingBits{1'b1}}, 12'h0};

  // How many bytes of a frame are left
  assign remaining_len  = frame_size_q-(req_addr_q-frame_start_q);

  assign blue_o   = old_beat_data_q[offset_q[AXIStrbWidthClog2+3-1:0] +:BlueWidth];
  assign green_o  = old_beat_data_q[offset_q[AXIStrbWidthClog2+3-1:0] + BlueWidth +:GreenWidth];
  assign red_o    = old_beat_data_q[offset_q[AXIStrbWidthClog2+3-1:0]
      + BlueWidth + GreenWidth +:RedWidth];

  // FSM to send requests
  always_comb begin
    frame_start_d     = frame_start_q;
    frame_size_d      = frame_size_q;
    burst_len_d       = burst_len_q;
    last_len_d        = last_len_q;
    first_req_d       = first_req_q;
    req_state_d       = req_state_q;
    req_addr_d        = req_addr_q;

    axi_req.ar        = '0;
    axi_req.ar.addr   = req_addr_q;
    axi_req.ar.burst  = 2'b01;    // Increasing burst
    axi_req.ar.cache  = 4'b0010;
    axi_req.ar.id     = '0;       // Explicitely state that we're using ID 0
    axi_req.ar.size   = AXIStrbWidthClog2[2:0];
    axi_req.ar_valid  = 1'b0;

    unique case (req_state_q)

      REQ: begin
        if(enable_i) begin
          axi_req.ar_valid = 1'b1;

          if(remaining_len > (burst_len_q+1)*AXIStrbWidth) begin
            if(req_addr_q[AXIAddrWidth-1:12] ==
                ((req_addr_q + (burst_len_q+1)*AXIStrbWidth) >> 12)) begin
              // Not the last request of frame
              axi_req.ar.len = burst_len_q;
              last_len_d     = burst_len_q;
            end else begin
              axi_req.ar.len =
                ((((req_addr_q + 4096) & addr_page_mask) - req_addr_q) >> AXIStrbWidthClog2)-1;
              last_len_d     =
                ((((req_addr_q + 4096) & addr_page_mask) - req_addr_q) >> AXIStrbWidthClog2)-1;
            end
          end else begin
            if(req_addr_q[AXIAddrWidth-1:12] == ((req_addr_q + remaining_len) >> 12)) begin
              // Last part of frame is within 4k boundary
              axi_req.ar.len = (remaining_len >> AXIStrbWidthClog2)-1;
              last_len_d     = (remaining_len >> AXIStrbWidthClog2)-1;
            end else begin
              axi_req.ar.len =
                ((((req_addr_q + 4096) & addr_page_mask) - req_addr_q) >> AXIStrbWidthClog2)-1;
              last_len_d     =
                ((((req_addr_q + 4096) & addr_page_mask) - req_addr_q) >> AXIStrbWidthClog2)-1;
            end
          end

          if(axi_resp.ar_ready) begin
            req_state_d = R_IDLE;
          end

        end else begin
          axi_req.ar_valid = 1'b0;

          first_req_d   = 1'b1;
          frame_start_d = start_addr;
          frame_size_d  = frame_size_i;
          burst_len_d   = burst_len_i;
          req_addr_d    = start_addr;
        end
      end

      R_IDLE: begin
        axi_req.ar_valid = 1'b0;

        if(enable_i) begin
          if((axi_resp.r_valid & axi_resp.r.last & !resp_last_q) | first_req_q) begin
            req_state_d = REQ;
            first_req_d = 1'b0;
            if((req_addr_q >= frame_start_q+frame_size_q-((last_len_q+1)*AXIStrbWidth))) begin
              // Was last REQ
              frame_start_d = start_addr;
              frame_size_d = frame_size_i;
              burst_len_d = burst_len_i;
              req_addr_d = start_addr;
            end else begin
              req_addr_d = req_addr_q + ((last_len_q+1)*AXIStrbWidth);
            end
          end
        end else begin
          req_state_d = REQ;
        end
      end

      default: begin
        req_state_d = REQ;
      end
    endcase
  end

  // FSM to accept beats
  always_comb begin
    accept_state_d = accept_state_q;
    axi_req.r_ready = 1'b0;
    new_beat_data_d = new_beat_data_q;

    unique case (accept_state_q)
      ACCEPT: begin
        axi_req.r_ready = 1'b1;
        if(axi_resp.r_valid) begin // TODO check req.r.resp
          new_beat_data_d = axi_resp.r.data; // Buffer beat to be processed after current one
          if((offset_q >> (AXIStrbWidthClog2+3)) > 1) begin
            accept_state_d = ACCEPT;
          end else accept_state_d = A_IDLE;
        end
        if(!enable_i) begin
          accept_state_d = ACCEPT;
        end
      end

      A_IDLE: begin
        axi_req.r_ready = 1'b0;
        if((process_started_q & !process_started_last) | !enable_i) begin
          accept_state_d = ACCEPT;
        end
      end

      default: begin
        accept_state_d = ACCEPT;
      end
    endcase
  end

  // Process responses
  always_comb begin
    valid_d           = valid_q;
    init_done_d       = init_done_q;
    old_beat_data_d   = old_beat_data_q;
    process_started_d = process_started_q;

    if(!enable_i) begin
      valid_d = 1'b0;
      init_done_d = 1'b0;
    end else begin
      if(!init_done_q & axi_resp.r_valid) begin
        if(offset_q == AXIDataWidth) begin
          valid_d = 1'b1;
        end else begin
          valid_d = 1'b0;
        end
        old_beat_data_d   = axi_resp.r.data;
        process_started_d = 1'b1;
        init_done_d       = 1'b1;
      end

      if(init_done_q) begin
        process_started_d = 1'b0;

        if(ready_i) begin
          if(offset_q[AXIStrbWidthClog2+3-1:0] == AXIDataWidth-PixelWidth) begin
            // was last pixel of beat
            old_beat_data_d   = new_beat_data_q;
            process_started_d = 1'b1;
            if(offset_q == AXIDataWidth-PixelWidth) begin
              valid_d = 1'b1;
            end else begin
              valid_d = 1'b0;
            end
          end
        end
      end
    end
  end

  // Offset counter
  always_comb begin
    offset_d = offset_q;

    if(enable_i) begin
      if(ready_i) begin
        offset_d = offset_q + PixelWidth; // Default when we sent out a pixel

        // We send out a pixel and at the same time fetch the next beat
        if ((accept_state_q == ACCEPT) & (axi_resp.r_valid) & (offset_q >= AXIDataWidth)) begin
          offset_d = offset_q - AXIDataWidth + PixelWidth;
        end

      // We fetched the next beat
      end else if
          ((accept_state_q == ACCEPT) & (axi_resp.r_valid) & (offset_q >= AXIDataWidth)) begin
        offset_d = offset_q - AXIDataWidth;
      end
    end else begin
      offset_d = AXIDataWidth[15:0];
    end
  end

  // Flip-Flops
  always_ff @(posedge clk_i, negedge rst_ni) begin
    if(!rst_ni) begin
      frame_start_q           <= '0;
      frame_size_q            <= '0;
      burst_len_q             <= '0;
      last_len_q              <= '0;
      first_req_q             <= 1'b1;
      req_state_q             <= REQ;
      req_addr_q              <= '0;

      init_done_q             <= 0;
      process_started_q       <= 0;
      process_started_last    <= 0;
      valid_q                 <= 0;

      accept_state_q          <= ACCEPT;
      old_beat_data_q         <= '0;
      new_beat_data_q         <= '0;

      offset_q                <= AXIDataWidth[15:0];
      resp_last_q             <= 1'b0;
    end else begin
      frame_start_q           <= frame_start_d;
      frame_size_q            <= frame_size_d;
      burst_len_q             <= burst_len_d;
      last_len_q              <= last_len_d;
      first_req_q             <= first_req_d;
      req_state_q             <= req_state_d;
      req_addr_q              <= req_addr_d;

      init_done_q             <= init_done_d;
      process_started_q       <= process_started_d;
      process_started_last    <= process_started_q;
      valid_q                 <= valid_d;

      accept_state_q          <= accept_state_d;
      old_beat_data_q         <= old_beat_data_d;
      new_beat_data_q         <= new_beat_data_d;

      offset_q                <= offset_d;
      resp_last_q             <= axi_resp.r.last;
    end
  end
endmodule
