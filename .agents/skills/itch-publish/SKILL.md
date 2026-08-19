---
name: itch-publish
description: >
  在 itch.io 上发布和更新游戏：创建项目页面，并使用 butler CLI（butler push）
  将构建上传到命名渠道。适用于 itch.io 发布、butler push、Windows/macOS/Linux/HTML5
  的渠道命名、上传版本管理，或将活动/发行构建发布到 itch.io。
---

# itch.io 发布（butler）

将构建发布到 itch.io 页面并持续更新。页面在浏览器中创建；所有上传都通过 itch.io 的命令行工具
**butler** 完成，而你会一直使用的命令只有一个：`butler push`。butler 会与上一个构建比较差异，
仅上传发生变化的内容。深入的 CI/CD 和标志详情位于 `references/butler-ci.md`。

## 使用时机

- 创建/更新 itch.io 项目页面、安装或登录 butler、使用 `butler push` 上传构建、选择渠道名称、
  管理上传版本，或将活动/演示/发行构建发布到 itch.io 时使用。
- 触发项：`butler push`、`butler login`、渠道、`.itch.toml`、“publish on itch”、
  “upload to itch”。

**不应使用的情况：**在 Steam 上发布（使用 `steam-publish`）；游戏创作活动的*范围规划*
（使用 `game-jam`——此 skill 仅处理上传机制）；构建游戏本身（使用引擎 skill）。

## 核心工作流

1. **创建项目页面**：前往 `itch.io/game/new`。设置 **Kind of project**：原生构建保持
   *Downloadable*，浏览器可玩游戏则选择 **HTML**（Web 构建必须如此——参见“常见陷阱”）。
   设置定价/可见性（准备就绪前保持 Draft）。
2. **安装 butler 并登录。**从 `itchio.itch.io/butler` 下载，将其添加到 `PATH`，
   然后运行 `butler login`（会打开浏览器进行授权）。使用 `butler version` 验证。
   CI 中改用 `BUTLER_API_KEY`——参见参考资料。
3. **准备可移植的构建文件夹**——只包含玩家实际运行的文件，不要包含其他内容。推送一个
   **文件夹**（或该文件夹的单个 `.zip`），**不要推送安装程序**，也**不要推送压缩包套压缩包的
   预压缩归档**（这会影响补丁效果；参见“常见陷阱”）。
4. **推送到渠道：**`butler push <dir> <user>/<game>:<channel>`。渠道名称决定平台标签
   （参见“模式”）。首次推送会上传全部内容；以后向同一渠道推送时只上传差异。
5. 如果渠道未被正确自动标记，请在 *Edit game* 页面上**设置平台/HTML 标签**，然后
   **Save**。对于浏览器游戏，还要将页面切换为 **HTML**，并将渠道标记为
   *playable in browser*。
6. **为构建设置版本**（可选但推荐）：使用 `--userversion 1.2.0` 或
   `--userversion-file build.txt`，以便控制玩家和更新 API 看到的版本字符串。
7. **后续更新**时，再次推送到*同一*渠道。使用 `butler status <user>/<game>` 查看渠道/构建，
   使用 `butler push-preview` 在发送前查看推送会更改什么。

## 模式

### 1. 你需要的唯一命令——`butler push`

```bash
# butler push <directory-or-zip> <user>/<game>:<channel>
butler push ./build/windows leafy/my-game:windows
butler push ./build/mac     leafy/my-game:osx
butler push ./build/linux   leafy/my-game:linux
butler push ./web           leafy/my-game:html   # browser build (also set page Kind = HTML)
```

### 2. 渠道命名控制平台标签（kebab-case、小写）

```text
Substring in channel name -> auto-applied tag:
  win / windows  -> Windows        linux -> Linux
  mac / osx      -> macOS          android -> Android
Multiple platforms in one channel are allowed: e.g. a Java jar:
  butler push ./jar leafy/my-game:win-linux-mac
Convention: lowercase words separated by dashes (windows-beta, osx-demo, soundtrack).
Tags are only the INITIAL guess — fix them anytime on the Edit game page (then Save).
```

### 3. 设置版本、验证和预览

```bash
butler version                              # print version; confirms install + PATH
butler login                                # authorize this machine (opens browser)

# Set an explicit version string instead of itch's auto-incrementing integer:
butler push ./build leafy/my-game:windows --userversion 1.2.0
butler push ./build leafy/my-game:windows --userversion-file build_number.txt

butler status leafy/my-game                 # list channels + latest builds/versions
butler push-preview ./build leafy/my-game:windows   # NEW/MODIFIED/DELETED/SAME, uploads nothing
```

### 4. 首次、隐藏和筛选推送

```bash
# Hide a brand-new channel from the page until you're ready (NEW channels only):
butler push ./build leafy/my-game:windows-beta --hidden

# Exclude files from the upload without copying the folder (--ignore is repeatable):
butler push ./build leafy/my-game:windows --ignore '*.pdb' --ignore '*.dSYM'

# Preview exactly what would be sent, without sending it:
butler push ./build leafy/my-game:windows --dry-run
```

## 常见陷阱

- **推送安装程序。**itch.io 为*可移植*构建打补丁；安装程序（`.exe`/`.msi`）会使补丁机制和
  itch 应用的自动更新失效，而且可能需要玩家没有的管理员权限。应推送解压后可运行的文件夹。
- **预压缩构建。**推送高度压缩的归档（或压缩包套压缩包）会让补丁变得很大——微小更改也会
  重写整个压缩数据块。推送未压缩文件；itch.io 会在服务端压缩。
- **文件夹中只有一个 `.zip`。**butler 会自动解压并推送其内容（避免“zip 套 zip”）。
  只有确实想将 zip 作为单个不透明文件上传时，才传递 `--no-auto-unzip`。
- **HTML5 游戏显示为下载。**必须设置两个开关：将页面 **Kind** 设为 *HTML*，并在首次推送后
  于 *Edit game* 页面将渠道标记为 *playable in browser*——渠道名称不会自动完成其中任何一步。
- **在现有渠道上使用 `--hidden` 会报错。**它仅适用于推送*创建*新渠道时。之后可从
  *Edit game* 取消隐藏。
- **渠道名称拼写错误会生成重复位置。**`windows` 和 `win-final` 是不同渠道，会创建独立下载项。
  提前确定渠道名称并重复使用。
- **30 GB 上限。**itch.io 会拒绝未压缩总大小超过 30 GB 的构建。
- **CI 日志中的机密。**公开日志中打印出的 `BUTLER_API_KEY` 已泄露——立即在 API 密钥页面撤销它。
  安全的 CI 用法请参见参考资料。

## 参考资料

- 有关使用 `BUTLER_API_KEY` 的 CI/CD（GitHub Actions/GitLab）、通过 `broth` 自动安装、
  完整标志列表和更新检查 API，请阅读 `references/butler-ci.md`。
- 主要文档：butler 手册——`itch.io/docs/butler`（安装、登录、推送）。

## 相关 skill

- `steam-publish` — 通过 SteamPipe 将同一游戏发布到 Steam（通常与 itch.io 一同发布）。
- `game-jam` — 大多数活动托管在 itch.io 上；此 skill 处理上传步骤。
- `prototype-fast` — 在 Draft/受限 itch 页面上分享早期原型以进行游戏测试。
