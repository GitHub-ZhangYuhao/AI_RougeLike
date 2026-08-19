---
name: unreal-packaging
description: >
  打包并发布 Unreal Engine 5 项目：Platforms 菜单中的 Package Project 流程、构建配置
  （Development 与 Shipping）、内容烘焙、打包设置和 Game Default Map，以及使用
  RunUAT BuildCookRun 的命令行构建。适用于打包构建、制作 shipping 构建、烘焙内容、
  配置打包设置，或用户提及 package Unreal、cook content、shipping build 或 BuildCookRun 时。
---

# Unreal 打包与烘焙

将 UE5 项目转换为可运行、可分发的构建：选择正确的构建配置、烘焙内容、设置启动地图，并通过
编辑器或命令行完成打包。目标版本为 **UE 5.8**。

## 何时使用

- 生成构建（测试版或发布版）、选择 Development 或 Shipping、烘焙内容、配置 Packaging /
  Maps & Modes 设置，或使用 `RunUAT BuildCookRun` 为 CI 自动执行构建时使用。
- 当项目具有 `*.uproject` 和 `Config/Default*.ini`，且目标是生成打包后的 player 而非在编辑器中
  运行时使用。

**不应使用的场景：** 商店提交/发布流程 → `steam-publish` / `itch-publish`。
编辑器阶段的玩法开发/迭代不属于打包。

## 核心工作流

1. **设置启动地图。** Project Settings → **Maps & Modes** → **Game Default Map** 是打包构建
   首先加载的内容。此处错误/为空是“打包后的游戏黑屏”最常见的原因。
2. **选择构建配置：** **Development**（默认；经过优化但保留 logging/stats/console 以供测试）与
   **Shipping**（启用全部优化并移除调试工具——用于发布）。`DebugGame`/`Debug` 用于调试引擎/
   游戏代码，不适合分发；仅有 Blueprint 的项目不支持 `DebugGame`。
3. **理解 cook 与 package 的区别。** **Cooking** 将资产转换为目标平台的格式，并打包到 `.pak`
   文件中。**Packaging** 将编译后的可执行文件和烘焙内容捆绑为一组独立、可分发的文件。
   Packaging 会在流程中执行 cook。
4. **从编辑器打包：** 打开 **Platforms** 菜单 → 选择平台（例如 Windows）→ 设置
   Binary Configuration → **Package Project** → 选择输出文件夹。
5. **或者从命令行构建：** 使用 Unreal Automation Tool（`RunUAT BuildCookRun`）完成可重复/CI 构建。
6. **调整 Packaging 设置**（Project Settings → **Packaging**）：指定要 cook 的 map/directory、
   full-rebuild、压缩以及是否构建所有 map。
7. **验证：** *运行打包后的构建*，不要只确认 cook 成功——启动可执行文件并确认它加载了正确的
   map 且能够运行。

## 模式

### 1. 编辑器打包（菜单路径）

```text
Platforms (toolbar)
  -> Windows
     -> Binary Configuration -> Development | Shipping
     -> Content Management -> Package Project
  -> choose/confirm the staging output folder
```

### 2. 使用 UAT 进行命令行构建（适合 CI）

```bash
# Cook + build + stage + pak + archive a Shipping Windows build.
RunUAT BuildCookRun \
  -project="C:/Path/MyGame.uproject" \
  -noP4 -platform=Win64 -clientconfig=Shipping \
  -cook -allmaps -build -stage -pak -archive \
  -archivedirectory="C:/Builds/MyGame"
```

`RunUAT` 位于 `Engine/Build/BatchFiles/`（Windows 上为 `RunUAT.bat`，macOS/Linux 上为
`RunUAT.sh`）。移除 `-allmaps` 并传入 `-map=Map1+Map2` 可只 cook 一部分 map。

### 3. 仅 cook（不打包），例如刷新内容

```bash
RunUAT BuildCookRun -project="C:/Path/MyGame.uproject" -noP4 \
  -platform=Win64 -clientconfig=Development -cook -skipstage
```

## 常见陷阱

- **打包构建加载黑色/空白关卡**——Game Default Map 未设置（或该 map 未被 cook）。请在
  Maps & Modes 中设置它，并确保将其纳入 cook。
- **发布 Development 构建**——Development 保留 logging/console/stats 且运行较慢；请发布
  **Shipping**。相反，Shipping 会移除 `UE_LOG`/console，因此调试仅在 Shipping 中出现的问题
  需要使用 Development 或 `Test`。
- **引用的 map/asset 在运行时缺失**——它未被 cook。请将其添加到 Packaging 设置中需要 cook 的
  map/directory，或 cook 所有 map。
- **目标平台上的构建失败**——未安装该平台的 SDK/toolchain（Windows build tool、Android SDK/NDK、
  主机 SDK）。请安装平台的前置条件。
- **期望使用 Blueprint Nativization**——它已**从 UE5 中移除**；不要依赖它提升性能。
  请进行性能分析，并将热点逻辑移至 C++（`unreal-cpp-gameplay`）。
- **首次 cook 非常慢**——shader 和所有资产都要从头 cook；后续 cook 会增量执行。不要将缓慢的
  首次 cook 误认为卡死。

## 参考资料

- 主要文档："Packaging Your Project"
  (`https://dev.epicgames.com/documentation/en-us/unreal-engine/packaging-your-project`) 以及
  Build Configurations / `BuildCookRun` 参考资料。

## 相关 skill

- `steam-publish` / `itch-publish` — 将打包构建分发到商店。
- `unreal-cpp-gameplay` — 在 BP nativization 消失后将热点逻辑移至 C++。
