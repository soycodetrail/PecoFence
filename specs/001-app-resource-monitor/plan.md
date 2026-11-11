# Implementation Plan: 用户级应用内存与CPU动态监控与关闭栅栏

**Branch**: `feature/process-fence` | **Date**: 2026-11-11 | **Spec**: [research.md](./research.md)  
**Input**: 用户请求支持点击查看自己打开的每个应用的内存与CPU占用，并支持一键杀死。

---

## 1. 架构总览与交互流程

```
[桌面 PecoFence 状态栅栏 (status_monitor.zh.ps1)]
       │
       ├─── 状态 A：总览模式 (Overview Mode)
       │    ├── CPU 总体负载 %
       │    ├── 物理内存已用 % (已用 GB / 总计 GB)
       │    └── [▶ 点击展开用户应用资源排行] ────► 点击写入 Toggle 标记
       │
       └─── 状态 B：用户应用下钻模式 (App Breakdown Mode)
            ├── 标题：【用户应用资源排行】
            ├── Chrome (PID: 34580) │ 315 MB │ CPU 2.1%  [❌ 关闭]
            ├── ChatGPT (PID: 47436) │ 232 MB │ CPU 0.0%  [❌ 关闭]
            ├── ...
            └── [◀ 点击返回总体系统概览] ─────────► 点击还原 Toggle 标记
```

---

## 2. 交付清单 (Deliverables)

1. `crates/app/assets/scripts/toggle_res.cmd`：控制展开/折叠状态切换的原子指令。
2. `crates/app/assets/scripts/status_monitor.zh.ps1`：综合状态监控脚本，融合系统总览与用户应用明细。
3. `specs/001-app-resource-monitor/quickstart.md`：操作指南与测试验证。
