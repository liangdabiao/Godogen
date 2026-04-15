# Godogen: Claude Code skills that build complete Godot 4 projects

[![Watch the video](https://img.youtube.com/vi/eUz19GROIpY/maxresdefault.jpg)](https://youtu.be/eUz19GROIpY)

[观看演示](https://youtu.be/eUz19GROIpY) · [提示词](demo_prompts.md)

你描述你想要的内容。AI pipeline 会设计架构、生成美术资源、编写每一行代码、从运行的游戏引擎中截取截图，并修复看起来不对的地方。输出是一个真正的 Godot 4 项目，包含组织良好的场景、可读的脚本和正确的游戏架构。支持 2D 和 3D，可在普通硬件上运行。

## 功能特点

- **三个 Claude Code skills** — 一个编排器在单个 100万 token 上下文中运行完整 pipeline（规划、构建、调试），而两个分支支持 skills 处理 Godot API 查询和可视化 QA，不会污染主上下文。
- **Godot 4 输出** — 真正的项目，包含正确的场景树、脚本和资源组织。
- **资源生成** — Gemini 创建精确的参考图和角色；xAI Grok 处理纹理和简单物体；Tripo3D 将图片转换为 3D 模型。动画精灵使用 Grok 视频生成并检测循环。预算意识：最大化每分钱产生的视觉效果。
- **GDScript 专业知识** — 自定义构建的语言参考和延迟加载的 API 文档，覆盖所有 850+ Godot 类，弥补 LLM 在 GDScript 训练数据上的不足。
- **可视化 QA 闭环** — 从运行的游戏中捕获实际截图，使用 Gemini Flash 和 Claude vision 进行分析。包含自由形式可视化调试的问答模式。能捕捉 z-fighting、缺失纹理、物理破损等问题。
- **可在普通硬件上运行** — 任何装有 Godot 和 Claude Code 的 PC 都能工作。

## 新增文档

本项目新增了以下功能文档，详细说明各模块的使用方法：

| 文档 | 说明 |
|------|------|
| [visual-qa.md](.claude/skills/godogen/visual-qa.md) | 可视化质量保证，使用 Gemini Flash 和 Claude vision 进行截图分析和问答 |
| [android-build.md](.claude/skills/godogen/android-build.md) | Android APK 导出配置和构建流程 |
| [sprite-gen.md](.claude/skills/godogen/sprite-gen.md) | 2D 精灵图动画生成，通过 302.ai API 创建角色动画序列 |
| [capture.md](.claude/skills/godogen/capture.md) | 游戏截图和视频捕获，支持 macOS 和 Linux 平台 |
| [test-harness.md](.claude/skills/godogen/test-harness.md) | 测试框架和可视化验证，SceneTree 脚本编写规范 |

## 快速开始

### 环境要求

- [Godot 4](https://godotengine.org/download/)（headless 或 editor）已在 PATH 中
- 已安装 [Claude Code](https://docs.anthropic.com/en/docs/claude-code)
- API keys 环境变量：
  - `GOOGLE_API_KEY` — [Google AI Studio](https://aistudio.google.com/)，用于 Gemini 图片生成（参考图、角色、精确工作）
  - `XAI_API_KEY` — [xAI Grok](https://console.x.ai/home)，用于图片/视频生成（纹理、简单物体）
  - `TRIPO3D_API_KEY` — [Tripo3D](https://platform.tripo3d.ai/)，用于图片转 3D 模型（仅 3D 游戏需要）
- Python 3 + pip（资源工具会自动安装依赖）
- 系统包：`mesa-utils`、`ffmpeg`（详细说明见 [setup.md](setup.md)，包含 macOS）
- 测试环境：Ubuntu、Debian 和 macOS

### 创建游戏项目

此仓库是 skill 开发源码。要开始制作游戏，运行 `publish.sh` 设置包含所有 skills 安装的新项目文件夹：

```bash
./publish.sh ~/my-game
./publish.sh --force ~/my-game  # 清理现有目标后重新发布
```

这会创建目标目录，包含 `.claude/skills/` 和 `CLAUDE.md`，然后初始化 git 仓库。在该文件夹中打开 Claude Code，告诉它要制作什么游戏 — `/godogen` skill 会处理后续一切。

### 在 VM 上运行

单次生成可能需要数小时。在云 VM 上运行可保持本地机器空闲，并为 Godot 的截图捕获提供 GPU。基本的 G4/T4 或 L4 GPU 的 GCE 实例即可。

无需保持终端打开整个运行过程。连接一个 [channel](https://code.claude.com/docs/en/channels#quickstart)（Telegram、Slack 等）来从手机发送提示并接收进度更新，或使用 [remote control](https://code.claude.com/docs/en/remote-control) 从任何浏览器管理会话。

## Claude Code 是唯一选择吗？

这些 skills 在不同设置下进行了测试。Claude Code 配合 Opus 4.6 可获得最佳结果。Sonnet 4.6 也可以工作，但需要用户更多指导。[OpenCode](https://opencode.ai/) 相当不错，移植 skills 也很简单——如果你在寻找替代方案，推荐它。

## 功能概览

### 可视化 QA（visual-qa）

运行在分支上下文中，使用 Claude 原生 vision。包含三种模式：

- **静态模式**：无运动场景（装饰、地形、UI）
- **动态模式**：有运动、动画或物理的场景
- **问答模式**：调试和调查，可针对截图提出任何问题

### Android 构建

支持将 Godot 项目导出为 debug APK。包含完整的 `export_presets.cfg` 配置模板和常见问题排查。

### 精灵图动画生成

通过 302.ai nano-banana-2 API 生成 NxN 动画精灵图。支持多种动画类型：idle、walk、run、attack、cast、jump、dance、death、dodge。

### 截图和视频捕获

支持 macOS（Metal）和 Linux（X11/xvfb + 可选 GPU）。硬件渲染时支持视频导出。

### 测试框架

SceneTree 脚本编写规范，支持控制台断言和模拟输入。

## 路线图

- 探索 C# 作为 GDScript 替代方案
- 发布完整的端到端游戏作为公开演示
- 探索 Bevy Engine 作为 Godot 替代方案

## 更新日志

**2026-04-03 — 单上下文架构**（当前）
- 将任务执行器合并到 godogen — 完整 pipeline 在单个 100万 token 上下文中运行
- 添加 godot-api skill（分支、Sonnet）用于 Godot 类 API 查询
- 添加 visual-qa skill（分支）使用 Gemini Flash、Claude vision 和问答模式
- 风险优先分解取代任务 DAG
- Android debug APK 导出

**2026-03-25 — xAI Grok 视频**
- 添加 xAI Grok 视频生成用于动画精灵（参考图 → 姿态 → 视频 → 帧 → 循环裁剪）
- 使用 BiRefNet 多信号抠图重写背景去除
- macOS 支持，原生 channel 状态更新

**2026-03-09 — 初始发布**
- 双 skill 架构：godogen 编排器 + godot-task 执行器（分支）
- Gemini 图片生成，Tripo3D 用于 3D 模型
- 通过 Gemini Flash 进行可视化 QA
- 截图和视频捕获，演示视频
- GDScript 参考系统，带延迟双层 API 查询

关注进度：[@alex_erm](https://x.com/alex_erm)
