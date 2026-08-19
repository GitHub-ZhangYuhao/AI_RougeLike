---
name: godot-export
description: >
  导出并构建 Godot 4.7 项目以供分发：安装导出模板、定义导出预设
  (Windows/macOS/Linux/Web/Android)、为 CI 运行无头命令行导出，以及处理 web
  (HTML5) COOP/COEP 和专用服务器/无头构建。导出 Godot 游戏、配置
  export_presets.cfg、为 web/桌面/mobile 构建，或从命令行自动构建时使用。
---

# Godot 导出与构建 (4.x)

通过导出预设和命令行将项目转换为可运行的平台构建，并处理 web/专用服务器中的易错点。
适用于 **Godot 4.7**。

## 何时使用

- 生成可发布构建时使用：安装导出模板、创建/编辑导出预设、从编辑器或无头 CLI（CI）导出，
  或排查 web (HTML5) 和专用服务器导出问题。

**不应使用的情况：** 商店发布流程 → `steam-publish`/`itch-publish`；服务器的网络代码 →
`godot-multiplayer`（此 skill 负责将其构建为无头版本）。

## 核心工作流

1. **安装与引擎版本匹配的导出模板：** 编辑器菜单 > *Manage Export Templates*（下载），
   或离线安装 `.tpz`。版本必须与编辑器完全匹配。
2. **在 *Project > Export* 中添加导出预设：** 选择平台（Windows Desktop、macOS、Linux、
   Web、Android、iOS），设置导出路径、图标、feature，以及资源包含/排除过滤器。
   预设保存到 `export_presets.cfg`。
3. 使用 *Export Project*（release）或 *Export PCK/ZIP* **从编辑器导出**。
4. 或使用 `--export-release "<preset name>" <output path>` **从 CLI 无头导出**，
   以实现自动化/CI。
5. **各平台注意事项：** Web 的线程需要跨源隔离（COOP/COEP）；Android 需要 SDK/keystore；
   macOS/iOS 分发时需要签名。
6. 发布前在目标平台上**冒烟测试构建**——导出的构建中 `res://` 为只读；应写入 `user://`。

## 模式

### 1. 无头 CLI 导出（适合 CI）

```bash
# Preset name must match exactly what's in Project > Export (quote it).
# Run from the project directory (where project.godot lives).
godot --headless --export-release "Windows Desktop" build/windows/game.exe
godot --headless --export-release "Linux/X11"       build/linux/game.x86_64
godot --headless --export-release "Web"             build/web/index.html

# Debug build (includes debug symbols / remote debug):
godot --headless --export-debug "Windows Desktop" build/windows/game_debug.exe

# Export only the data pack (no executable):
godot --headless --export-pack "Linux/X11" build/game.pck
```

### 2. 以无头模式运行项目（专用服务器/测试）

```bash
# No window/GPU — for a server build or automated runs.
godot --headless --path . res://server_main.tscn
# Quit after N main-loop iterations (frames, NOT seconds) — handy for a headless smoke test:
godot --headless --path . --quit-after 600
```

### 3. 在运行时检测构建上下文

```gdscript
func _ready() -> void:
    if OS.has_feature("dedicated_server") or DisplayServer.get_name() == "headless":
        _start_server_only()          # skip rendering/UI on a headless server
    if OS.has_feature("web"):
        _apply_web_tweaks()
    # Custom feature tags (added per preset) are also queryable:
    # if OS.has_feature("demo"): limit_content()
```

### 4. 选择在导出后仍有效的写入路径

```gdscript
# res:// is READ-ONLY in exported games. Always write to user://.
func save_path() -> String:
    return "user://savegame.tres"     # resolves to the OS app-data dir

func _ready() -> void:
    print(OS.get_user_data_dir())     # where user:// actually lives
```

## 常见陷阱

- **“No export template found”。** 模板必须与编辑器版本完全匹配（包括 beta/rc）。
  升级 Godot 后，通过 *Manage Export Templates* 重新下载。
- **CLI 中的预设名称不匹配。** 如果预设名为 `"Windows Desktop"`，
  `--export-release "Windows"` 就会失败。名称区分大小写和空格；请加引号。
- **Web 构建显示空白页面/线程错误。** 使用线程的 HTML5 构建要求服务器发送
  `Cross-Origin-Opener-Policy: same-origin` 和
  `Cross-Origin-Embedder-Policy: require-corp`（为 `SharedArrayBuffer` 提供跨源隔离）。
  必须通过 HTTP(S) 提供服务，不能以 `file://` 打开。itch.io 为此提供了
  “SharedArrayBuffer support”开关。
- 导出的构建中，运行时**写入 `res://` 会失败**（只读、已打包）。使用 `user://`。
- **构建中缺少资源。** 非资源文件（例如外部 `.json`、`.txt`）不会自动包含——通过预设的
  *Resources > Filters to export non-resource files* 添加它们（例如 `*.json`）。
- **Android 导出需要设置：** Editor Settings 中的 Android SDK/JDK 路径、debug 或 release
  **keystore**，以及网络游戏所需的 `INTERNET` 权限。
- **macOS/iOS 分发需要签名/notarization**；未签名的 macOS 应用会被 Gatekeeper 阻止。
- **Debug 与 release。** `--export-debug` 启用远程调试和调试检查；发布时使用
  `--export-release`。

## 参考资料

- 有关 `export_presets.cfg` 结构、所有实用 CLI flag、自定义 feature tag、PCK/扩展补丁、
  加密，以及各平台设置（Android keystore、macOS 签名、web header），请阅读
  `references/presets-and-cli.md`。

## 相关 skill

- `godot-multiplayer` — 以无头模式导出的专用服务器代码。
- `steam-publish` / `itch-publish` — 将构建交付给玩家。
- `prototype-fast` / `game-jam` — 用于分享的快速 web/桌面构建。
