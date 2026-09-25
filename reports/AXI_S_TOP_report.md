# AXI_S_TOP 基本数据通路报告

## 组成与接口

`SA_TOP 结果接口 → fifo_out → fifo2axi → wr_* AXI-Stream`。

顶层只连接两个已有模块，共用 `sys_ckg` 和低有效复位 `tpu_rst_n`。
本项目沿用用户指定的 M/S 命名；S 通路的外部 AXI-Stream 接口发送数据。

| 接口 | 作用 |
|---|---|
| data_out / dat_out_vld / dat_out_last | SA 结果数据、写入有效及末拍标记 |
| cpu_tpu_en_sync | 使能输出桥 |
| cpu_tpu_start_sync | 清零输出拍数统计 |
| cpu_cpt_mode | 00/01 对应 USER=0；10/11 对应 USER=1 |
| rpt_cpt_cyc | 默认 32 bit，统计成功 AXI 输出握手次数 |
| wr_tvalid / wr_tready / wr_tdata / wr_tlast | 输出流握手、数据及末拍标记 |
| wr_tkeep / wr_tstrb / wr_tid / wr_tdest / wr_tuser | KEEP/STRB 全 1，ID/DEST 为 0，USER 表示数值类型 |

默认输入为 packed `data_out[15:0][31:0]`，即 16 路、每路 32 bit，打包成 512 bit，lane 0 对应低 32 bit，不做数值转换。
FIFO 深度经项目讨论后默认设置为 8，且仍可通过参数覆盖。DATA 与 LAST 同项存储；FIFO 队首直接连接输出桥的 FWFT 接口。
`fifo_out_re` 由输出桥产生，每次 AXI 握手消费一项；遇到 READY 停顿，桥保持待发送数据。
任务期间应保持 `cpu_cpt_mode` 稳定；START 应在传输开始前发出，避免与计数事件重叠。

## 基本仿真

TB 为 `tb/tb_AXI_S_TOP.sv`，直接例化新顶层，用已知的 lane 数据检查打包、输出顺序及 LAST，同时检查 sideband 和输出拍数。
测试范围是基本数据流，未进行覆盖率收集或完整验证计划。

运行命令（项目目录下）：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File sim/run_questa_axi_top.ps1 -Module AXI_S_TOP
```

使用本机 QuestaSim 2021.1，独立 work 库。既有桥的端口声明使用 `-svinputport=var` 兼容选项；新顶层显式声明输入端口类型。
每次运行保存 compile.log、simulate.log 和 waves.wlf；可在 Questa GUI 中打开 waves.wlf 查看内部信号。

## 实测结果

2026-09-25 将 S 口 TB 改为 `wr_tready` 从仿真开始恒为 1、先于 `wr_tvalid` 后，本机 Questa 重新运行通过。FIFO 默认深度仍为 8，且不导出 `fifo_out_full`。

| 项目 | 结果 |
|---|---|
| 编译 / 仿真 | 均为 0 errors、0 warnings |
| SA 写入 / AXI 输出 | 8 拍 / 8 拍，每拍 512 bit |
| DATA | 16 路 32 bit 正确打包，完整 512 bit 逐拍比对一致 |
| LAST | 仅第 8 拍为 1，输出端共记录 1 次 |
| READY / VALID 时序 | READY 从 0 ns 起保持为 1，先于 VALID；随后连续接收 |
| sideband | mode=10，USER=1；KEEP/STRB 全 1，ID/DEST 为 0 |
| 输出计数 | rpt_cpt_cyc=8 |
| 完成状态 | WR VALID 回到 0，仿真于 170 ns 正常结束 |

成功握手时间为 75、85、95、105、115、125、135、145 ns。
对应数据低 32 bit 为 `80000000、80000010、80000020、80000030、80000040、80000050、80000060、80000070`（十六进制）；其余 lane 也参与完整数据比较。第 b 拍、第 i 路为 `32'h8000_0000 + b*16 + i`，高 16 bit 非零，避免仅测到半个数据字。

```text
AXI_S_TOP PASS: sent=8 received=8 last=1 rpt_cpt_cyc=8 width=512
```

- [顶层 RTL](E:/CodexWork/AXI_TOP/rtl/AXI_S_TOP.sv)
- [基本数据流 TB](E:/CodexWork/AXI_TOP/tb/tb_AXI_S_TOP.sv)
- [编译日志](E:/CodexWork/AXI_TOP/sim/questa/AXI_S_TOP/20260925_180747_5646df2e/compile.log)
- [仿真逐拍日志](E:/CodexWork/AXI_TOP/sim/questa/AXI_S_TOP/20260925_180747_5646df2e/simulate.log)
- [Questa 波形](E:/CodexWork/AXI_TOP/sim/questa/AXI_S_TOP/20260925_180747_5646df2e/waves.wlf)

`fifo_out → fifo2axi` 集成 TB 另外传输了 49 拍，覆盖四种 `cpu_cpt_mode`、重复 READY 反压、LAST、USER、计数器清零和使能撤销，结果同样为 0 errors、0 warnings。

- [集成 TB](E:/CodexWork/AXI_TOP/tb/tb_fifo_out_fifo2axi.sv)
- [集成编译日志](E:/CodexWork/AXI_TOP/sim/questa/fifo_out/20260925_152715_a82793ac/compile.log)
- [集成仿真日志](E:/CodexWork/AXI_TOP/sim/questa/fifo_out/20260925_152715_a82793ac/simulate.log)

本次结论限定为上述基本端到端传输。没有展开覆盖率收集或综合时序签核。`fifo_out` 不导出 FULL；系统调度必须保证 AXI 背压期间的未消费结果不超过深度 8。FIFO 内部保留满保护，但调度越界的输入拍没有外部重试机制。
