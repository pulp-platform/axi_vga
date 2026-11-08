// Copyright 2026 CheshireAra contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Test-only finite extension of the public interface arrangement in
// pulp-platform/axi_vga test/tb_axi_vga.sv at 3718b9930f94a9eaad8ee50b4bccc71df0403084.
// The original test is retained in this stage's inputs/official_3718b993.
module tb_e_vga_unit;
  timeunit 1ns;
  timeprecision 1ps;
  `include "axi/typedef.svh"
  typedef logic [47:0] addr_t;
  typedef logic [1:0] id_t;
  typedef logic [63:0] data_t;
  typedef logic [7:0] strb_t;
  typedef logic [1:0] user_t;
  `AXI_TYPEDEF_ALL(vga, addr_t, id_t, data_t, strb_t, user_t)
  typedef struct packed {
    logic valid, write;
    addr_t addr;
    logic [31:0] wdata;
    logic [3:0] wstrb;
  } reg_req_t;
  typedef struct packed {logic ready, error; logic [31:0] rdata;} reg_rsp_t;
  logic clk=0, rst_n=0;
  always #2.5ns clk=~clk;
  vga_req_t req;
  vga_resp_t rsp='0;
  reg_req_t cfg_req='0;
  reg_rsp_t cfg_rsp;
  logic hs,vs;
  logic [4:0] red,blue;
  logic [5:0] green;
  axi_vga #(
    .RedWidth(5),.GreenWidth(6),.BlueWidth(5),.HCountWidth(24),.VCountWidth(24),
    .AXIAddrWidth(48),.AXIDataWidth(64),.AXIStrbWidth(8),.AXIIdWidth(2),
    .AXIUserWidth(2),.BufferDepth(16),.MaxReadTxns(24),
    .axi_req_t(vga_req_t),.axi_resp_t(vga_resp_t),.axi_r_chan_t(vga_r_chan_t),
    .reg_req_t(reg_req_t),.reg_resp_t(reg_rsp_t)
  ) dut (.clk_i(clk),.rst_ni(rst_n),.test_mode_en_i(1'b0),
    .reg_req_i(cfg_req),.reg_rsp_o(cfg_rsp),.axi_req_o(req),.axi_resp_i(rsp),
    .hsync_o(hs),.vsync_o(vs),.red_o(red),.green_o(green),.blue_o(blue));

  typedef struct packed {addr_t addr,base; id_t id; int unsigned epoch;} pending_t;
  pending_t pending[$];
  string profile="timing";
  int unsigned case_id=0,epoch=0,cases=0;
  addr_t frame_base=48'h0010fff0;
  longint unsigned cycle=0,checks=0,errors=0,ar_total=0,r_total=0;
  longint unsigned rgb_total=0,black_total=0,mmio_total=0;
  longint unsigned credit_full_total=0,ar_stall_total=0,inner_stall_total=0;
  longint unsigned gap_pending_total=0;
  int unsigned ar_in_epoch=0;
  int credit_ref=0,logical_pending=0;
  int ar_wait=0,r_gap=0;
  bit slave_ar_stalls=0,withhold_r=0,last_r_accepted=0;
  bit pixel_gold=1,black_gold=0,active=0;
  logic [31:0] control_shadow=6,divider_shadow=1;
  int unsigned ref_phase=0,hpos=0,vpos=0,ref_frame=0;
  bit raster_running=0;
  vga_ar_chan_t held_ar;
  vga_r_chan_t held_r;
  bit ar_held=0,r_held=0;

  function automatic longint unsigned now_ps();return longint'($realtime/1ps);endfunction
  function automatic logic [15:0] pixel(input int unsigned i,e);
    logic [4:0] r,b;logic [5:0] g;
    r=(3*i+5*e+1)&31;g=(5*i+7*e+2)&63;b=(11*i+3*e+4)&31;
    return {r,g,b};
  endfunction
  function automatic logic [63:0] response_word(input pending_t p);
    logic [63:0] value;int unsigned first;
    first=int'((p.addr-p.base)>>1);value=0;
    for(int j=0;j<4;j++)value[j*16+:16]=pixel(first+j,p.epoch);
    return value;
  endfunction
  task automatic check(input logic good,input string label,
                       input logic [63:0] actual=0,expected=0);
    checks++;
    if(good!==1'b1)begin
      errors++;
      $display("[E_VGA_ERROR] profile=%s case=%0d epoch=%0d cycle=%0d time_ps=%0d label=%s actual=%h expected=%h",
        profile,case_id,epoch,cycle,now_ps(),label,actual,expected);
    end
  endtask
  task automatic control_error(input string label);
    $display("[E_VGA_CONTROL_ERROR] profile=%s case=%0d epoch=%0d cycle=%0d label=%s",
      profile,case_id,epoch,cycle,label);
    forever @(negedge clk);
  endtask
  task automatic clocks(input int unsigned n);repeat(n)@(negedge clk);#1ps;endtask
  task automatic reset_common;
    @(negedge clk);#1ps;
    $display("[E_VGA_RESET] case=%0d epoch=%0d time_ps=%0d asserted=1 external_pending=%0d logical_pending=%0d credit=%0d",
      case_id,epoch,now_ps(),pending.size(),logical_pending,credit_ref);
    rst_n=0;cfg_req='0;
    repeat(5)@(negedge clk);#1ps;rst_n=1;
    $display("[E_VGA_RESET] case=%0d epoch=%0d time_ps=%0d asserted=0",case_id,epoch,now_ps());
    clocks(3);
  endtask
  task automatic write_reg(input int unsigned offset,input logic [31:0] value);
    @(negedge clk);#1ps;
    cfg_req='{valid:1,write:1,addr:addr_t'(offset),wdata:value,wstrb:4'hf};
    do @(posedge clk);while(cfg_rsp.ready!==1'b1);
    check(cfg_rsp.error===0,"config_write_error",cfg_rsp.error,0);
    @(negedge clk);#1ps;cfg_req='0;
  endtask
  task automatic read_reg(input int unsigned offset,input logic [31:0] expected);
    @(negedge clk);#1ps;
    cfg_req='{valid:1,write:0,addr:addr_t'(offset),wdata:0,wstrb:4'hf};
    do @(posedge clk);while(cfg_rsp.ready!==1'b1);
    check(cfg_rsp.error===0,"config_read_error",cfg_rsp.error,0);
    check(cfg_rsp.rdata===expected,"config_readback",cfg_rsp.rdata,expected);
    @(negedge clk);#1ps;cfg_req='0;
  endtask
  task automatic configure(input int unsigned next_epoch,input bit positive,
                           input int unsigned burst_len,input addr_t start);
    int unsigned offsets[14]='{0,4,8,12,16,20,24,28,32,36,40,44,48,52};
    logic [31:0] values[14];
    epoch=next_epoch;frame_base=start;ar_in_epoch=0;
    values='{positive?32'd6:32'd0,32'd8,32'd16,32'd2,32'd3,32'd3,
      32'd8,32'd1,32'd2,32'd1,start[31:0],{16'd0,start[47:32]},32'd256,32'(burst_len)};
    for(int i=0;i<14;i++)begin write_reg(offsets[i],values[i]);read_reg(offsets[i],values[i]);end
    $display("[E_VGA_CONFIG] profile=%s case=%0d epoch=%0d time_ps=%0d start=%h bytes=256 divider=8 h=16,2,3,3 v=8,1,2,1 pol=%0d len=%0d",
      profile,case_id,epoch,now_ps(),frame_base,positive,burst_len);
  endtask
  task automatic start_display(input bit positive);
    write_reg(0,positive?7:1);
  endtask
  task automatic wait_frames(input int unsigned count);
    int n;
    n=0;
    while((!raster_running || ref_frame<count) && n<100000)begin clocks(1);n++;end
    if(n==100000)control_error("finite_frame_wait_incomplete");
  endtask
  task automatic stop_and_drain(input bit positive);
    int n,quiet;
    bit idle_seen;
    write_reg(0,positive?6:0);n=0;quiet=0;idle_seen=0;
    while(quiet<64 && n<4096)begin
      clocks(1);n++;
      if(pending.size()==0 && logical_pending==0 && credit_ref==0 &&
         req.ar_valid===0 && rsp.r_valid===0)begin
        // The first idle sample starts the interval; count only full clocks.
        if(idle_seen)quiet++;idle_seen=1;
      end else begin quiet=0;idle_seen=0;end
    end
    $display("[E_VGA_DRAIN] profile=%s case=%0d epoch=%0d cycle=%0d clocks=%0d quiet=%0d external_pending=%0d logical_pending=%0d credit=%0d",
      profile,case_id,epoch,cycle,n,quiet,pending.size(),logical_pending,credit_ref);
    if(quiet!=64)control_error("old_responses_not_drained");
    check({red,green,blue}===16'd0,"disabled_rgb",{red,green,blue},0);
    check(hs===(positive?0:1) && vs===(positive?0:1),"disabled_sync",{hs,vs},positive?0:3);
  endtask
  task automatic begin_case(input int unsigned id);
    case_id=id;cases++;pixel_gold=1;black_gold=0;slave_ar_stalls=0;withhold_r=0;r_gap=0;
    reset_common();active=1;
    $display("[E_VGA_CASE] event=begin profile=%s case=%0d cycle=%0d",profile,case_id,cycle);
  endtask
  task automatic end_case;
    $display("[E_VGA_CASE] event=end profile=%s case=%0d cycle=%0d checks=%0d errors=%0d rgb=%0d black=%0d ar=%0d r=%0d",
      profile,case_id,cycle,checks,errors,rgb_total,black_total,ar_total,r_total);
    active=0;
  endtask

  // The endpoint queue uses only accepted public AR/R, never a DUT internal address.
  // R fields are retained while VALID is held, including across a deliberate gap.
  always @(negedge clk or negedge rst_n)begin
    if(!rst_n)begin rsp='0;ar_wait=0;r_gap=0;end
    else begin
      rsp.aw_ready=0;rsp.w_ready=0;rsp.b_valid=0;rsp.b='0;
      if(ar_wait>0)begin rsp.ar_ready=0;ar_wait--;end else rsp.ar_ready=1;
      if(rsp.r_valid && !last_r_accepted)begin end
      else begin
        rsp.r_valid=0;rsp.r='0;
        if(r_gap>0)begin if(pending.size()!=0)gap_pending_total++;r_gap--;end
        else if(!withhold_r && pending.size()!=0)begin
          rsp.r_valid=1;rsp.r.id=pending[0].id;rsp.r.data=response_word(pending[0]);
          rsp.r.resp=axi_pkg::RESP_OKAY;rsp.r.last=1;rsp.r.user=0;
        end
      end
    end
  end

  // All sampling precedes the DUT NBA update. Post samples are explicitly labelled.
  always @(posedge clk)begin : observer
    pending_t p;
    bit ar_accept,r_accept,fifo_pop,logical_ar,logical_r,tick;
    int effective_div;
    logic [15:0] expected_pixel;
    cycle++;
    if(!rst_n)begin
      pending.delete();credit_ref=0;logical_pending=0;last_r_accepted=0;
      control_shadow=6;divider_shadow=1;ref_phase=0;hpos=0;vpos=0;ref_frame=0;
      raster_running=0;ar_held=0;r_held=0;
    end else begin
      ar_accept=req.ar_valid===1 && rsp.ar_ready===1;
      r_accept=rsp.r_valid===1 && req.r_ready===1;
      fifo_pop=dut.axi_resp_split.r_valid===1 && dut.axi_req_split.r_ready===1 && dut.axi_resp_split.r.last===1;
      logical_ar=dut.axi_req.ar_valid===1 && dut.axi_resp.ar_ready===1;
      logical_r=dut.axi_resp.r_valid===1 && dut.axi_req.r_ready===1;
      last_r_accepted=r_accept;
      if(active)begin
        $display("[E_VGA_AXI_UNUSED] case=%0d epoch=%0d cycle=%0d time_ps=%0d aw_valid=%b aw_ready=%b aw_id=%h aw_addr=%h aw_len=%h aw_size=%h w_valid=%b w_ready=%b w_data=%h w_strb=%h w_last=%b b_valid=%b b_ready=%b b_id=%h b_resp=%h",
          case_id,epoch,cycle,now_ps(),req.aw_valid,rsp.aw_ready,req.aw.id,req.aw.addr,req.aw.len,req.aw.size,req.w_valid,rsp.w_ready,req.w.data,req.w.strb,req.w.last,rsp.b_valid,req.b_ready,rsp.b.id,rsp.b.resp);
        check(!$isunknown({req.aw_valid,req.w_valid,req.ar_valid,req.r_ready,rsp.r_valid,rsp.ar_ready}),"axi_control_known");
        check(req.aw_valid===0 && req.w_valid===0,"read_only_master",{req.aw_valid,req.w_valid},0);
        if(ar_held)check(req.ar_valid===1 && req.ar===held_ar,"ar_held_stable");
        if(r_held)check(rsp.r_valid===1 && rsp.r===held_r,"r_held_stable");
      end
      ar_held=req.ar_valid===1 && rsp.ar_ready!==1;held_ar=req.ar;
      r_held=rsp.r_valid===1 && req.r_ready!==1;held_r=rsp.r;
      if(active && (req.ar_valid!==0 || ar_held))begin
        $display("[E_VGA_AXI] case=%0d epoch=%0d cycle=%0d time_ps=%0d side=external channel=AR valid=%b ready=%b id=%h addr=%h len=%h size=%h burst=%h cache=%h lock=%b prot=%h qos=%h region=%h user=%h",
          case_id,epoch,cycle,now_ps(),req.ar_valid,rsp.ar_ready,req.ar.id,req.ar.addr,req.ar.len,req.ar.size,req.ar.burst,req.ar.cache,req.ar.lock,req.ar.prot,req.ar.qos,req.ar.region,req.ar.user);
        if(req.ar_valid && !rsp.ar_ready)ar_stall_total++;
      end
      if(active && (rsp.r_valid!==0 || r_held))
        $display("[E_VGA_AXI] case=%0d epoch=%0d cycle=%0d time_ps=%0d side=external channel=R valid=%b ready=%b id=%h data=%h resp=%h last=%b user=%h",
          case_id,epoch,cycle,now_ps(),rsp.r_valid,req.r_ready,rsp.r.id,rsp.r.data,rsp.r.resp,rsp.r.last,rsp.r.user);
      if(ar_accept)begin
        if(active)begin
          check(req.ar.len===0 && req.ar.size===3 && req.ar.burst===1 && req.ar.id===0 && req.ar.cache===2,"external_ar_shape");
          check(req.ar.addr>=frame_base && req.ar.addr<frame_base+256 && req.ar.addr[2:0]===0,"external_ar_range",req.ar.addr,frame_base);
          check(req.ar.addr===frame_base+48'(8*(ar_in_epoch%32)),"external_ar_sequence",req.ar.addr,frame_base+48'(8*(ar_in_epoch%32)));
          check(credit_ref<16 || fifo_pop,"credit_over_issue",credit_ref,16);
        end
        p='{addr:req.ar.addr,base:frame_base,id:req.ar.id,epoch:epoch};pending.push_back(p);ar_total++;ar_in_epoch++;
        if(slave_ar_stalls && ar_total%8==3)ar_wait=9;
      end
      if(r_accept)begin
        check(pending.size()!=0,"response_without_request");
        if(pending.size()!=0)begin
          p=pending.pop_front();check(rsp.r.id===p.id && rsp.r.last===1 && rsp.r.resp===0,"response_header");
          check(rsp.r.data===response_word(p),"endpoint_actual_data",rsp.r.data,response_word(p));
        end
        r_total++;
      end
      if(logical_ar)begin
        logical_pending+=int'(dut.axi_req.ar.len)+1;
        if(active)$display("[E_VGA_AXI] case=%0d epoch=%0d cycle=%0d time_ps=%0d side=fetcher channel=AR valid=1 ready=1 id=%h addr=%h len=%h size=%h burst=%h cache=%h",
          case_id,epoch,cycle,now_ps(),dut.axi_req.ar.id,dut.axi_req.ar.addr,dut.axi_req.ar.len,dut.axi_req.ar.size,dut.axi_req.ar.burst,dut.axi_req.ar.cache);
      end
      if(logical_r)logical_pending--;
      if(active && dut.axi_resp.r_valid===1)begin
        $display("[E_VGA_AXI] case=%0d epoch=%0d cycle=%0d time_ps=%0d side=fetcher channel=R valid=%b ready=%b id=%h data=%h resp=%h last=%b user=%h",
          case_id,epoch,cycle,now_ps(),dut.axi_resp.r_valid,dut.axi_req.r_ready,dut.axi_resp.r.id,dut.axi_resp.r.data,dut.axi_resp.r.resp,dut.axi_resp.r.last,dut.axi_resp.r.user);
        if(!dut.axi_req.r_ready)inner_stall_total++;
      end
      if(active && (fifo_pop || ar_accept || credit_ref==16 || rsp.r_valid!==1'b0 || dut.axi_resp.r_valid!==1'b0))
        $display("[E_VGA_CREDIT] case=%0d epoch=%0d cycle=%0d time_ps=%0d ar_accept=%b fifo_valid=%b fifo_ready=%b fifo_last=%b reference_before=%0d dut_actual=%0d split_ar_valid=%b external_ar_valid=%b external_rvalid=%b external_rready=%b logical_rvalid=%b logical_rready=%b",
          case_id,epoch,cycle,now_ps(),ar_accept,dut.axi_resp_split.r_valid,dut.axi_req_split.r_ready,dut.axi_resp_split.r.last,credit_ref,dut.counter_q,dut.axi_req_split.ar_valid,req.ar_valid,rsp.r_valid,req.r_ready,dut.axi_resp.r_valid,dut.axi_req.r_ready);
      if(credit_ref==16 && !fifo_pop && dut.axi_req_split.ar_valid===1 && req.ar_valid===0 && rsp.ar_ready===1)credit_full_total++;
      credit_ref+=int'(ar_accept)-int'(fifo_pop);
      if(active)begin check(credit_ref>=0 && credit_ref<=16,"credit_range",credit_ref,16);check(logical_pending>=0,"logical_response_balance",logical_pending,0);end

      effective_div=(divider_shadow&255)==0?1:int'(divider_shadow&255);
      tick=control_shadow[0] && ref_phase==0;
      if(active)begin
        $display("[E_VGA_PIN] case=%0d epoch=%0d cycle=%0d time_ps=%0d sample=pre hsync=%b vsync=%b red=%h green=%h blue=%h",
          case_id,epoch,cycle,now_ps(),hs,vs,red,green,blue);
        check(hs===(control_shadow[1]?(raster_running && hpos>=18 && hpos<21):!(raster_running && hpos>=18 && hpos<21)),"hsync_pre",hs,0);
        check(vs===(control_shadow[2]?(raster_running && vpos>=9 && vpos<11):!(raster_running && vpos>=9 && vpos<11)),"vsync_pre",vs,0);
        check(!$isunknown({hs,vs,red,green,blue}),"pins_known");
        if(!raster_running || hpos>=16 || vpos>=8)check({red,green,blue}===16'd0,"blanking_black",{red,green,blue},0);
        if(tick && raster_running && hpos<16 && vpos<8)begin
          if(pixel_gold && (ref_frame==1 || ref_frame==2))begin
            expected_pixel=pixel(16*vpos+hpos,epoch);rgb_total++;
            check({red,green,blue}===expected_pixel,"pixel",{red,green,blue},expected_pixel);
          end
          if(black_gold && ref_frame<2)begin black_total++;check({red,green,blue}===16'd0,"withheld_R_black",{red,green,blue},0);end
        end
      end
      if(!control_shadow[0])begin raster_running=0;hpos=0;vpos=0;ref_frame=0;end
      else if(tick)begin
        if(!raster_running)begin raster_running=1;hpos=0;vpos=0;ref_frame=0;end
        else if(hpos==23)begin hpos=0;if(vpos==11)begin vpos=0;ref_frame++;end else vpos++;end
        else hpos++;
      end
      ref_phase=ref_phase<effective_div-1?ref_phase+1:0;
      if(cfg_req.valid===1 && cfg_rsp.ready===1)begin
        mmio_total++;
        $display("[E_VGA_MMIO] case=%0d epoch=%0d cycle=%0d time_ps=%0d addr=%h write=%b wdata=%h wstrb=%h rdata=%h error=%b",
          case_id,epoch,cycle,now_ps(),cfg_req.addr,cfg_req.write,cfg_req.wdata,cfg_req.wstrb,cfg_rsp.rdata,cfg_rsp.error);
        if(cfg_req.write && !cfg_rsp.error)case(cfg_req.addr[5:0])
          0:control_shadow=cfg_req.wdata&7;
          4:divider_shadow=cfg_req.wdata&255;
          default:begin end
        endcase
      end
      #1ps;
      if(active)$display("[E_VGA_PIN] case=%0d epoch=%0d cycle=%0d time_ps=%0d sample=post hsync=%b vsync=%b red=%h green=%h blue=%h",
        case_id,epoch,cycle,now_ps(),hs,vs,red,green,blue);
    end
  end
  always @(hs or vs or red or green or blue)if(active && rst_n)
    $display("[E_VGA_PIN_CHANGE] case=%0d epoch=%0d time_ps=%0d hsync=%b vsync=%b red=%h green=%h blue=%h",
      case_id,epoch,now_ps(),hs,vs,red,green,blue);

  task automatic timing_profile;
    begin_case(901);configure(1,0,7,48'h0010fff0);start_display(0);wait_frames(4);stop_and_drain(0);end_case();
    begin_case(902);configure(2,1,0,48'h00010010fff0);start_display(1);wait_frames(4);stop_and_drain(1);end_case();
  endtask
  task automatic flow_profile;
    longint unsigned before_stall,before_full,before_inner;
    begin_case(903);configure(3,0,7,48'h0010fff0);slave_ar_stalls=1;before_stall=ar_stall_total;
    start_display(0);wait_frames(4);slave_ar_stalls=0;stop_and_drain(0);
    if(ar_stall_total==before_stall)control_error("AR_backpressure_window_not_reached");end_case();
    begin_case(904);configure(4,0,15,48'h0010fff0);before_full=credit_full_total;before_inner=inner_stall_total;
    start_display(0);wait_frames(4);stop_and_drain(0);
    if(credit_full_total==before_full || inner_stall_total==before_inner)control_error("credit_full_window_not_reached");end_case();
    begin_case(905);configure(5,0,7,48'h0010fff0);withhold_r=1;pixel_gold=0;black_gold=1;
    start_display(0);wait_frames(2);black_gold=0;withhold_r=0;wait_frames(4);
    $display("[E_VGA_LIMITATION] case=905 underflow_seamless_recovery=not_accepted action=common_reset");
    reset_common();pixel_gold=1;configure(6,0,7,48'h0010fff0);start_display(0);wait_frames(4);stop_and_drain(0);end_case();
  endtask
  task automatic restart_profile;
    longint unsigned accepted_before,gap_before;
    begin_case(906);pixel_gold=0;configure(7,0,7,48'h0010fff0);start_display(0);wait_frames(4);
    while(!(raster_running && vpos==8 && hpos==0))clocks(1);
    stop_and_drain(0);pixel_gold=1;configure(8,0,7,48'h0010fff0);start_display(0);wait_frames(4);stop_and_drain(0);end_case();
    begin_case(907);pixel_gold=0;configure(9,0,7,48'h0010fff0);start_display(0);wait_frames(1);
    // Retain public accepted requests for the selected stop, without retracting RVALID.
    withhold_r=1;
    while(!(raster_running && ref_frame==1 && vpos==3 && hpos==9))clocks(1);
    withhold_r=0;clocks(1); // Present one real queued R before the 32-clock gap.
    r_gap=32;gap_before=gap_pending_total;
    if(pending.size()<=1)control_error("inflight_stop_window_not_reached");
    stop_and_drain(0);if(gap_pending_total-gap_before!=32)control_error("R_delay_with_pending_not_reached");
    pixel_gold=1;configure(10,0,7,48'h0010fff0);start_display(0);wait_frames(4);stop_and_drain(0);end_case();
    begin_case(908);pixel_gold=0;configure(11,0,7,48'h0010fff0);withhold_r=1;accepted_before=ar_total;start_display(0);
    while(ar_total==accepted_before)clocks(1);clocks(3);
    if(pending.size()==0)control_error("inflight_reset_window_not_reached");
    reset_common();withhold_r=0;pixel_gold=1;configure(12,0,7,48'h0010fff0);start_display(0);wait_frames(4);stop_and_drain(0);end_case();
  endtask
  initial begin
    void'($value$plusargs("E_VGA_UNIT_PROFILE=%s",profile));
    $display("[E_VGA_META] version=1 kind=unit profile=%s clock_ps=5000 width=16 height=8 bytes=256 divider=8",profile);
    case(profile)"timing":timing_profile();"flow":flow_profile();"restart":restart_profile();default:control_error("unsupported_profile");endcase
    check(cases==(profile=="timing"?2:3),"case_count",cases,profile=="timing"?2:3);
    check(rgb_total==(profile=="timing"?512:768),"formal_rgb_count",rgb_total,profile=="timing"?512:768);
    check(black_total==(profile=="flow"?256:0),"formal_black_count",black_total,profile=="flow"?256:0);
    check(pending.size()==0 && logical_pending==0 && credit_ref==0,"final_pending_zero");
    $display("[E_VGA_DONE] kind=unit profile=%s cases=%0d checks=%0d errors=%0d formal_rgb=%0d formal_black=%0d ar=%0d r=%0d mmio=%0d ar_stall=%0d inner_stall=%0d credit_full=%0d",
      profile,cases,checks,errors,rgb_total,black_total,ar_total,r_total,mmio_total,ar_stall_total,inner_stall_total,credit_full_total);
    if(errors!=0)$fatal(1,"E_VGA_UNIT_FAIL");
    $display("E_VGA_UNIT_PASS profile=%s",profile);$finish;
  end
endmodule
