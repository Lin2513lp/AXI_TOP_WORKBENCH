# AXI_M_TOP 基本数据通路报告

## 组成与接口

`rd_* AXI-Stream → axi2fifo → fifo_in → TPU 读数据接口`。

顶层只连接两个已有模块，共用 `sys_ckg` 和低有效复位 `tpu_rst_n`。
本项目沿用用户指定的 M/S 命名；M 通路的外部 AXI-Stream 接口接收数据。

| 接口 | 作用 |
|---|---|
| cpu_tpu_en_sync / cpu_tpu_start_sync | 使能及启动接收；每个以 TLAST 结束的数据包需要启动 |
| rd_tvalid / rd_tready / rd_tdata / rd_tlast | 输入流握手、数据及末拍标记 |
| rd_tkeep / rd_tstrb / rd_tid / rd_tdest / rd_tuser | 保留已有桥接口；满字宽传输，不存储这些 sideband |
| fifo_in_re | TPU 消费当前 FIFO 队首 |
| fifo_empty | FIFO 无有效数据 |
| fifo_in_rdata / fifo_in_rd_dat_last | 当前队首的 DATA 和 LAST |

数据宽度默认 512 bit。经项目讨论，FIFO 深度默认设置为 8，提前满门限默认设置为 7，二者仍可通过参数覆盖。
内部 `fifo_in_pre_full` 反馈给桥以控制 READY。DATA 和 LAST 同项存储，FIFO 使用 FWFT：非空时数据已可见，读使能在时钟上升沿消费当前项。

## 基本仿真

TB 为 `tb/tb_AXI_M_TOP.sv`，直接例化新顶层。先拉高 VALID 和首拍 DATA，再发 START 使 READY 拉高；暂停 FIFO 读取以触发 PRE_FULL，随后逐拍读出并打印完整 512 bit 数据。
测试范围是基本数据流，未进行覆盖率收集或完整验证计划。

运行命令（项目目录下）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sim/run_questa_axi_top.ps1 -Module AXI_M_TOP
```

使用本机 QuestaSim 2021.1，独立 work 库。既有桥的端口声明使用 `-svinputport=var` 兼容选项；新顶层显式声明输入端口类型。
每次运行保存 compile.log、simulate.log 和 waves.wlf；可在 Questa GUI 中打开 waves.wlf 查看内部信号。

## 实测结果

2026-09-25 简化 TB 并明确体现 VALID 先于 READY、FIFO PRE_FULL 反压后，本机 QuestaSim 重新运行通过。

| 项目 | 结果 |
|---|---|
| 编译 / 仿真 | 均为 0 errors、0 warnings |
| AXI 输入 / FIFO 消费 | 10 拍 / 10 拍，每拍 512 bit |
| DATA | 全部 512 bit 逐拍比对一致，无多拍、少拍或乱序 |
| LAST | 仅第 10 拍为 1 |
| 初始时序 | 首拍 VALID、DATA 先出现；START 后 READY 才拉高 |
| 反压 | 暂停 FIFO 读取，7 拍入队时 PRE_FULL 拉高；恢复读取后继续握手 |
| 完成状态 | FIFO 为空，仿真于 330 ns 正常结束 |

成功消费时间为 235、245、255、265、275、285、295、305、315、325 ns。第 `beat` 拍为 16 份相同的 32 bit 数值 `A5000000 + beat`，日志逐拍打印完整 512 bit，并做全宽比较。

```text
AXI_M_TOP PASS: 10 beats, VALID before READY, PRE_FULL stall
```

- [顶层 RTL](E:/CodexWork/AXI_TOP/rtl/AXI_M_TOP.sv)
- [基本数据流 TB](E:/CodexWork/AXI_TOP/tb/tb_AXI_M_TOP.sv)
- [编译日志](E:/CodexWork/AXI_TOP/sim/questa/AXI_M_TOP/20260925_162440_39c7775f/compile.log)
- [仿真逐拍日志](E:/CodexWork/AXI_TOP/sim/questa/AXI_M_TOP/20260925_162440_39c7775f/simulate.log)
- [Questa 波形](E:/CodexWork/AXI_TOP/sim/questa/AXI_M_TOP/20260925_162440_39c7775f/waves.wlf)

直接连接 `axi2fifo → fifo_in` 的精简 TB 另用深度 4、9 拍数据验证同一时序：PRE_FULL 于 3 拍入队后出现，FIFO 逐拍打印 `A5000000` 至 `A5000008`，末拍 LAST=1。

- [集成 TB](E:/CodexWork/AXI_TOP/tb/tb_axi2fifo_fifo_in.sv)
- [集成仿真日志](E:/CodexWork/AXI_TOP/sim/questa/fifo_in/20260925_162440_35e642bf/simulate.log)

本次结论限定为上述基本端到端传输。本次未进行综合时序签核。
