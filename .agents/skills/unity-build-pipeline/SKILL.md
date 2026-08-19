---
name: unity-build-pipeline
description: >
  构建并发布 Unity 6.3 LTS 播放器：构建设置与场景、播放器/质量设置、IL2CPP 与 Mono
  脚本后端、托管代码剥离、脚本化 BuildPipeline.BuildPlayer，以及 CI/无头构建。
  适用于配置或自动化构建、选择脚本后端、缩减构建体积，或用户提到 Unity 构建、
  播放器设置、IL2CPP、代码剥离或 Addressables 时。
---

# Unity 构建流水线

配置、编写脚本并自动化 Unity 6.3 LTS 播放器构建：场景、平台目标、脚本后端、
代码剥离和无头/CI 构建。面向 **Unity 6.3 LTS (6000.3)**。

## 何时使用

- 适用于设置 Build Settings/Profiles、选择平台和脚本后端（Mono 与 IL2CPP）、
  通过托管代码剥离缩减构建体积、使用 `BuildPipeline.BuildPlayer` 编写可重复构建脚本，
  或连接 CI/无头构建。
- 适用于项目包含 `ProjectSettings/EditorBuildSettings.asset` 或 CI 构建脚本时。

**何时不应使用：**端到端编写 CI 服务配置属于 DevOps；本技能涵盖 Unity 侧的构建 API
和设置。主机/平台认证细节受平台保密协议约束。商店提交 → `steam-publish` / `itch-publish`。

## 核心工作流

1. **列出要构建的场景**（File → Build Profiles/Settings → Scene List，或
   `EditorBuildSettings.scenes`）。只有已列出且启用的场景会被发布；场景 0 是启动场景。
2. **选择平台目标**，并在需要时切换活动构建目标
   （`BuildTarget` / `EditorUserBuildSettings`）。
3. **选择脚本后端**（Player Settings）：**Mono**（迭代快，适合桌面平台）与
   **IL2CPP**（AOT C++；许多平台的强制要求，性能更好，更难逆向）。IL2CPP 需要安装
   该平台的 C++ 工具链。
4. **调整体积/性能：**设置 Managed Stripping Level（Disabled → Minimal → Low → Medium → High），
   并通过 `link.xml` 保护仅由反射使用的代码。按平台设置 Quality Settings。
5. **使用 `BuildPipeline.BuildPlayer(BuildPlayerOptions)` 编写构建脚本**，并**检查返回的
   `BuildReport`**——任何非 `Succeeded` 的结果都必须使流水线失败。
6. **在 CI 中以无头模式运行**：使用 `-batchmode -quit -executeMethod`，并检查退出码。
7. **验证**实际输出可以运行（启动播放器），而不只是构建过程没有抛出异常。

## 模式

### 1. 带结果检查的脚本化构建

```csharp
using UnityEditor;
using UnityEditor.Build.Reporting;
using UnityEngine;

public static class BuildScript
{
    [MenuItem("Build/Windows x64")]
    public static void BuildWindows()
    {
        var options = new BuildPlayerOptions
        {
            scenes = new[] { "Assets/Scenes/Main.unity", "Assets/Scenes/Level1.unity" },
            locationPathName = "Builds/Windows/Game.exe",
            target = BuildTarget.StandaloneWindows64,
            options = BuildOptions.None,            // add BuildOptions.Development for a dev build
        };

        BuildReport report = BuildPipeline.BuildPlayer(options);
        BuildSummary summary = report.summary;

        if (summary.result != BuildResult.Succeeded)
            throw new System.Exception($"Build failed: {summary.totalErrors} errors");
        Debug.Log($"Build OK: {summary.totalSize} bytes in {summary.totalTime}");
    }
}
```

### 2. 无头 / CI 调用

```bash
# Exit code is 0 on success; -quit ensures the editor closes; -nographics for build servers.
Unity -batchmode -quit -nographics \
  -projectPath "/path/to/Project" \
  -executeMethod BuildScript.BuildWindows \
  -logFile -
```

### 3. 使用 `link.xml` 保护被剥离的代码

```xml
<!-- Assets/link.xml — keep types the linker can't see are used (reflection, JSON, plugins). -->
<linker>
  <assembly fullname="MyGameRuntime" preserve="all"/>
</linker>
```

## 常见陷阱

- **场景可在 Editor 中加载，但在构建中缺失**——它不在 Build Settings 场景列表中
  （或已禁用）。`SceneManager.LoadScene` 只能看到已列出的场景。
- **IL2CPP 构建在新机器上失败**——未安装平台 C++ 工具链（例如 Windows 构建工具、
  Android NDK）。Mono 没有此要求。
- **仅在构建中出现 `MissingMethodException`/`TypeLoadException`**——托管代码剥离移除了
  仅由反射使用的代码。降低剥离级别，或在 `link.xml` 中添加保留条目。
- **将“BuildPlayer 已返回”视为成功**——务必检查 `BuildReport.summary.result`；
  它可能在存在错误时仍然返回。
- **Addressables 内容过期/缺失**——Addressables（`com.unity.addressables`）需要
  *单独*构建内容（Build → Addressables），并使用指向正确加载路径的 Profile；
  仅构建播放器不会重新构建这些内容。
- **发布 Development 构建**——`BuildOptions.Development` 会启用 Profiler/调试且速度较慢；
  发布版请使用 `BuildOptions.None`。

## 参考资料

- 如需完整的**多平台 CI 构建脚本**（目标切换、版本标记、参数解析、退出码）
  和 Addressables 内容构建调用，请阅读 `references/ci-build-script.md`。
- 主要文档：`ScriptReference/BuildPipeline.BuildPlayer`、Unity Manual 构建章节
  （播放器设置、托管代码剥离）。

## 相关技能

- `steam-publish` / `itch-publish`——分发刚刚构建的播放器。
- `unity-csharp-scripting`——构建脚本使用的编辑器脚本约定。
