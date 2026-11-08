// Copyright 2026 CheshireAra contributors.
// Licensed under the Apache License, Version 2.0, see LICENSE for details.
// SPDX-License-Identifier: Apache-2.0
// Give DC the finite RGB565/48-bit-address/64-bit-data fetcher type parameters.
// The DUT interface and state are unchanged by this implementation-only wrapper.
`include "axi/typedef.svh"
package e_vga_fetcher_impl_pkg;
  typedef logic [47:0] addr_t;
  typedef logic [1:0] id_t;
  typedef logic [63:0] data_t;
  typedef logic [7:0] strb_t;
  typedef logic [1:0] user_t;
  `AXI_TYPEDEF_ALL(vga, addr_t, id_t, data_t, strb_t, user_t)
endpackage

module v01_vga_fetcher_impl (
  input logic clk_i,
  input logic rst_ni,
  input logic enable_i,
  output e_vga_fetcher_impl_pkg::vga_req_t axi_req_o,
  input e_vga_fetcher_impl_pkg::vga_resp_t axi_resp_i,
  input logic [63:0] start_addr_i,
  input logic [31:0] frame_size_i,
  input logic [7:0] burst_len_i,
  output logic [4:0] red_o,
  output logic [5:0] green_o,
  output logic [4:0] blue_o,
  output logic valid_o,
  input logic ready_i
);
  axi_vga_fetcher #(
    .RedWidth(5), .GreenWidth(6), .BlueWidth(5),
    .AXIAddrWidth(48), .AXIDataWidth(64), .AXIStrbWidth(8),
    .axi_req_t(e_vga_fetcher_impl_pkg::vga_req_t),
    .axi_resp_t(e_vga_fetcher_impl_pkg::vga_resp_t)
  ) dut (
    .clk_i, .rst_ni, .enable_i, .axi_req_o, .axi_resp_i,
    .start_addr_i, .frame_size_i, .burst_len_i,
    .red_o, .green_o, .blue_o, .valid_o, .ready_i
  );
endmodule
