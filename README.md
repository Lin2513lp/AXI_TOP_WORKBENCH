> 源码范围：仅本模块 RTL、内部子模块及独立 TB；其他模块源码请进入对应工作台。`code/` 不收录联调包装、构建脚本、Makefile 或说明文件。

# AXI_TOP Design Workbench

**[Open the AXI_TOP Workbench](https://lin2513lp.github.io/AXI_TOP_WORKBENCH/AXI_TOP_WORKBENCH.html)**

Independent AXI4-Stream input and output paths with FIFO buffering for TPU_TOP. The workbench runs in a browser and requires no installation.

## Workbench contents

- AXI_M_TOP: AXI input through axi2fifo into fifo_in.
- AXI_S_TOP: fifo_out through fifo2axi to the AXI output.
- 512-bit streaming data, ready/valid handshakes, and packet boundaries.
- Architecture reports, timing diagrams, simulation captures, and source browsing.

## Source files

[`code/`](code/) contains only this module’s RTL, internal submodules and standalone HDL testbenches. There are **9 RTL/TB files**. Other modules are available from their respective workbenches. [`source-manifest.json`](source-manifest.json) lists the retained source hashes.


## Repository layout

| Path | Contents |
| --- | --- |
| [`AXI_TOP_WORKBENCH.html`](AXI_TOP_WORKBENCH.html) | Main design workbench |
| [`code/`](code/) | This module’s RTL and independent HDL testbenches |
| [`source-manifest.json`](source-manifest.json) | Source inventory and checksums |
| [`index.html`](index.html) | English project introduction and workbench link |

## Using the project

Open the workbench to browse the design report, waveforms and this module’s RTL/TB. Run simulation in the original local project environment.

## Related workbenches

- [TPU_CRG](https://github.com/Lin2513lp/TPU_CRG_WORKBENCH)
- [AHB_SLAVE](https://github.com/Lin2513lp/AHB_SLAVE_WORKBENCH)
- [SA_TOP](https://github.com/Lin2513lp/sa-workbench)
- [PE_MP](https://github.com/Lin2513lp/pe-mp-workbench)
