# AXI VGA

This repository contains a free and open-source fully synthesizable VGA controller
that requests the pixel data directly using configurable AXI bursts. It is part of the PULP ecosystem.

## TODOs
* [ ] Support multiple AXI beats per pixel
* [ ] Support all AXI data widths
  * [ ] 8
  * [ ] 16
  * [x] 32
  * [x] 64
  * [x] 128
  * [x] 256
  * [x] 512
  * [x] 1024
* [ ] Support unaligned pixel sizes (i.e. 24 bit pixels)
