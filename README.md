# AXI_TOP Design Workbench

**[Open the AXI_TOP Workbench](https://lin2513lp.github.io/AXI_TOP_WORKBENCH/AXI_TOP_WORKBENCH.html)**

Independent AXI4-Stream input and output paths with FIFO buffering for TPU_TOP. The workbench runs in a browser and requires no installation.

## Workbench contents

- AXI_M_TOP: AXI input through axi2fifo into fifo_in.
- AXI_S_TOP: fifo_out through fifo2axi to the AXI output.
- 512-bit streaming data, ready/valid handshakes, and packet boundaries.
- Architecture reports, timing diagrams, simulation captures, and source browsing.

## Source files

[`code/`](code/) contains the current source snapshot from the shared `AXI_TOP` project. Relative paths and file contents are preserved, including RTL, testbenches, Makefiles, file lists, and available helper scripts. The workbench's code viewer displays this same snapshot.

There are **17 project files** in this snapshot. [`source-manifest.json`](source-manifest.json) records the shared-directory mapping and SHA-256 checksums. Generated simulator databases, waveform dumps, editor temporary files, and license logs are excluded.

## Repository layout

| Path | Contents |
| --- | --- |
| [`AXI_TOP_WORKBENCH.html`](AXI_TOP_WORKBENCH.html) | Main design workbench |
| [`code/`](code/) | Shared-project source files and build entry points |
| [`source-manifest.json`](source-manifest.json) | Source inventory and checksums |
| [`index.html`](index.html) | English project introduction and workbench link |

## Using the project

Open the workbench through the link above to browse the report, code, and waveforms. For simulation, clone this repository, enter `code/AXI_M_TOP/` or `code/AXI_S_TOP/`, and use the corresponding Makefile in a configured Linux EDA environment. The original tool paths and environment variables in the shared Makefile are preserved; configure these for your installation.

## Related workbenches

- [TPU_CRG](https://github.com/Lin2513lp/TPU_CRG_WORKBENCH)
- [AHB_SLAVE](https://github.com/Lin2513lp/AHB_SLAVE_WORKBENCH)
- [SA_TOP](https://github.com/Lin2513lp/sa-workbench)
- [PE_MP](https://github.com/Lin2513lp/pe-mp-workbench)
