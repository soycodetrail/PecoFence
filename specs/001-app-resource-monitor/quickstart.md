# Quickstart & Verification: 用户应用资源监控下钻栅栏

## 1. 验证目标
- 点击状态栅栏中的 `▶ 点击查看每个应用内存/CPU占用` 即可实时无缝下钻到用户应用资源榜单。
- 榜单自动剔除系统服务、后台进程、explorer 与 PecoFence，仅显示用户自己开的应用。
- 显示每个应用的内存占用 (MB) 及估算 CPU 负载 %。
- 点击任意应用末尾的 `❌` 即可调用 `killapp.cmd` 彻底关闭应用。
- 点击 `◀ 点击返回系统概览` 可瞬间折叠回系统总体 CPU/内存看板。

## 2. 启用方式
在 PecoFence 的任何栅栏右键：
1. **添加小工具 (Tools)** → **脚本 (Script)**。
2. 脚本选择：`crates/app/assets/scripts/status_monitor.zh.ps1`。
3. 即可在桌面上获得支持无感交互下钻的“高能监控”栅栏。
