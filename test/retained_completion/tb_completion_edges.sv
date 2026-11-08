// Copyright 2026 CheshireAra contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Direct public-port tests. No force or DUT-state assignment is used.
module tb_completion_edges;
  timeunit 1ns; timeprecision 1ps;
  `include "axi/typedef.svh"
  typedef logic [47:0] addr_t;
  typedef logic [1:0] id_t;
  typedef logic [63:0] data_t;
  typedef logic [7:0] strb_t;
  typedef logic [1:0] user_t;
  `AXI_TYPEDEF_ALL(vga, addr_t, id_t, data_t, strb_t, user_t)
  logic clk=0, rst_n=0, enable=0, consume=0;
  always #2.5ns clk=~clk;
  vga_req_t req;
  vga_resp_t rsp='0;
  logic [4:0] red,blue; logic [5:0] green; logic valid;
  axi_vga_fetcher #(.AXIAddrWidth(48),.AXIDataWidth(64),.AXIStrbWidth(8),
    .axi_req_t(vga_req_t),.axi_resp_t(vga_resp_t)) dut
    (.clk_i(clk),.rst_ni(rst_n),.enable_i(enable),.axi_req_o(req),.axi_resp_i(rsp),
     .start_addr_i(64'h1000),.frame_size_i(32'd256),.burst_len_i(8'd0),
     .red_o(red),.green_o(green),.blue_o(blue),.valid_o(valid),.ready_i(consume));
  int cases=0,checks=0,errors=0,ar=0,responses=0,pending=0,maximum=0;
  int held_clocks=0,req_saved=0,saved_new=0,startup_new=0;
  task automatic check(input logic good,input string label);
    checks++;
    if(good!==1)begin errors++;$display("EDGE_ERROR case=%0d label=%s ar=%0d r=%0d pending=%0d",cases,label,ar,responses,pending);end
  endtask
  task automatic reset;
    @(negedge clk);#1ps;rst_n=0;enable=0;rsp='0;consume=0;
    repeat(3)@(negedge clk);#1ps;rst_n=1;
    repeat(2)@(negedge clk);
    ar=0;responses=0;pending=0;maximum=0;cases++;
  endtask
  task automatic step(input bit rv=0,last=0,arr=1,ready=0,
                      input int want_ar=-1,want_ready=-1);
    @(negedge clk);#1ps;
    enable=1;consume=ready;rsp='0;rsp.ar_ready=arr;
    rsp.r_valid=rv;rsp.r.last=last;rsp.r.data=64'h13579bdf2468ace0;
    @(posedge clk);
    if(want_ar>=0)check(req.ar_valid===1'(want_ar),"ARVALID sequence");
    if(want_ready>=0)check(req.r_ready===1'(want_ready),"RREADY sequence");
    $display("EDGE_PORT case=%0d ar_valid=%b ar_ready=%b ar_addr=%h r_valid=%b r_ready=%b r_last=%b before=%0d",
      cases,req.ar_valid,rsp.ar_ready,req.ar.addr,rsp.r_valid,req.r_ready,rsp.r.last,pending);
    if(rv && req.r_ready)begin check(pending>0,"response has accepted request");responses++;pending--;end
    if(req.ar_valid && arr)begin ar++;pending++;end
    if(pending>maximum)maximum=pending;
    check(pending>=0 && pending<=2,"maximum two pending single-beat requests");
    #1ps;
  endtask
  task automatic prefetch(input bit ready=0);
    step(0,0,1,ready,1);step(0,0,1,ready,0);
    step(0,0,1,ready,1);step(0,0,1,ready,0);
    check(ar==2 && pending==2,"two independent startup requests");
  endtask
  initial begin
    // RLAST is unrelated when RVALID is zero. Its transitions issue no requests.
    reset();prefetch();
    repeat(4)begin step(0,1,1,0,0);step(0,0,1,0,0);end
    check(ar==2 && responses==0,"invalid LAST has no completion");
    // Two accepted beats fill the fetcher's pixel storage. Hold the next valid
    // LAST until actual RREADY, with an unchanged payload and no new completion.
    reset();prefetch();
    step(1,1,1,0,0,1);step(0,0,1,0,1,0);
    step(1,1,1,0,0,1);step(0,0,1,0,1,0);
    repeat(8)begin step(1,1,1,0,0,0);held_clocks++;end
    check(ar==4 && responses==2 && pending==2,"stalled LAST cannot issue repeatedly");
    // Accumulate pixel demand so both single-beat responses can be accepted on
    // consecutive clocks. AR backpressure holds the request state for one edge.
    reset();prefetch(1);repeat(16)step(0,0,1,1,0);
    step(1,1,1,1,0,1);step(1,1,0,1,1,1);req_saved++;
    step(0,0,1,1,1);step(1,1,1,1,0,1);saved_new++;
    step(0,0,1,1,1);step(0,0,1,1,0);step(0,0,1,1,1);
    repeat(4)step(0,0,1,1,0);
    check(ar==5 && responses==3 && pending==2,"saved and new completions both consumed once");
    // The first idle edge consumes the startup token. A simultaneous accepted
    // completion must remain available after the next request handshake.
    reset();step(0,0,1,1,1);step(1,1,1,1,0,1);startup_new++;
    step(0,0,1,1,1);step(0,0,1,1,0);step(0,0,1,1,1);
    repeat(4)step(0,0,1,1,0);
    check(ar==3 && responses==1 && pending==2,"startup token preserves accepted completion");
    check(held_clocks==8 && req_saved==1 && saved_new==1 && startup_new==1,"all edge cases reached");
    // Reset is the explicit cancellation boundary for the final pending reads.
    @(negedge clk);#1ps;rst_n=0;enable=0;rsp='0;
    repeat(2)@(negedge clk);
    $display("EDGE_DONE cases=%0d checks=%0d errors=%0d held=%0d req_saved=%0d saved_new=%0d startup_new=%0d max_pending=%0d",
      cases,checks,errors,held_clocks,req_saved,saved_new,startup_new,maximum);
    if(errors)$fatal(1,"EDGE_FAIL");
    $display("EDGE_PASS");$finish;
  end
  initial begin #2ms;$fatal(1,"EDGE_DEADLINE");end
endmodule
