---
name: steam-publish
description: >
  使用 Steamworks 和 SteamPipe 在 Steam 上发布或更新游戏：配置 depot 和 package、使用 steamcmd
  上传构建、将构建设为某个分支的上线版本，并执行发布检查清单。适用于 Steam 发布、
  app_build.vdf/steamcmd 上传、depot、beta 分支或商店页面发布。
---

# Steam 发布（Steamworks + SteamPipe）

将完成的构建发布到 Steam 商店页面。两条轨道并行推进，且发布前都必须获批：**商店页面**
（展示内容）和**构建**（SteamPipe 上传 + 发布检查清单）。此 skill 是操作检查清单；
深入的构建脚本、CI/CD 和故障排除详情位于 `references/steampipe-build-scripts.md`。

## 使用时机

- 设置 Steam 应用、构建/编辑商店页面、配置 depot 和 package、通过 SteamPipe/steamcmd 上传构建、
  管理 beta 分支，或发布和更新 Steam 游戏时使用。
- 触发项：`steam_appid.txt`、Steamworks SDK `tools/ContentBuilder`、`app_build_*.vdf`、
  `steamcmd`、“publish on Steam”、“depot”、“set build live”。

**不应使用的情况：**在 itch.io 上发布（使用 `itch-publish`）；在游戏内编写 Steamworks **API**
（成就/云存档/overlay 属于引擎 SDK 集成，不在此处）；商店/财务*建议*（定价策略、税务）——
请用户咨询 Steamworks 文档及其自己的顾问。

## 前置条件（按顺序执行一次）

1. **合作伙伴账户 + Steam Direct 费用。**每个新应用都需要支付可回收的 Steam Direct 费用
   （撰写本文时每个应用 USD $100）。你会收到一个 **App ID**——可在 Steamworks 主页找到。
   将 App ID 视为下方所有操作的关键。
2. **使用最小权限的专用构建账户。**构建需要使用合作伙伴组中的 Steam 账户，并拥有
   **Edit App Metadata** 和 **Publish App Changes To Steam** 权限。创建一个仅有这些权限的
   *独立*构建账户（不要使用管理员登录）。发布应用还需要 **Manage pricing and discounts**。
3. **在上传机器上下载 Steamworks SDK。**SteamPipe 工具位于 `tools/ContentBuilder/` 下。

> 安全说明：切勿将账户密码或 `config.vdf` 登录令牌提交到仓库。
> 支持的令牌工作流请参见参考资料中的 CI/CD 章节。

## 核心工作流

1. **配置应用（App Admin）。**
   - 在 *Installation* 下设置**启动选项**（各操作系统的可执行文件路径 + 参数）。对于子文件夹中的
     exe，请在 Executable 字段中填写子文件夹——不要带开头的斜杠/点。
   - 在 *Depots* 页面添加 **depot**（depot 是一组文件）。为每个 depot 命名
     （“Base Content”、“Windows Content”）。除非 depot 确实特定于操作系统或语言，
     否则保留 *[All languages]* / *[All OSes]*。
   - **向自己授予 depot：**在 *Associated Packages & DLC* 页面将其添加到你的
     **Developer Comp** package，否则你不会拥有自己上传的内容。
   - **发布**配置。未发布的配置是上传失败最常见的原因。
2. **构建商店页面（展示轨道）。**填写图形资源、描述、标签、预告片和系统要求。完成后点击
   **Mark as ready for review**。商店审核约需 3–5 个工作日；至少在期望上线日期前 **7 天**提交。
   发布前必须保持 **Coming Soon** 至少 **2 周**。
3. **创建构建脚本。**从下方“模式”中的简单应用构建 `.vdf` 开始；多 depot/多平台应用使用
   depot 脚本（参见参考资料）。脚本将本地文件映射到 depot，并指定构建输出/日志的位置。
4. **引导 steamcmd 并上传。**先运行一次 `steamcmd` 让它自更新，然后运行构建（见“模式”）。
   steamcmd 将文件切分为块（约 1 MB），只上传发生变化的块，并注册全局 **BuildID**。
5. **将构建设为某分支的上线版本。**前往 `https://partner.steamgames.com/apps/builds/<AppID>`，
   选择构建，点击 **Preview Change**，然后点击 **Set Build Live Now** 将其设为某分支的上线版本。
   先在 beta 分支上测试（分支设置见 `references/steampipe-build-scripts.md`）。
6. **执行 Game Build 检查清单**并点击 **Mark as ready for review**（必须先提交商店展示内容，
   才能进行构建审核）。两条轨道都必须获批。
7. **手动发布。**获批且 Coming Soon 满足时间要求后，使用绿色 **Release App** 按钮 →
   **Publish Now** → **Release Now**。获批的游戏**不会**自行发布。
8. **后续更新**时，上传新构建并将其设为 `default` 的上线版本（手动），或先发布到 beta 分支。
   参见 `references/steampipe-build-scripts.md`。

## 模式

### 1. SteamPipe ContentBuilder 布局（Steamworks SDK）

```text
tools/ContentBuilder/
  builder/         steamcmd.exe (Windows)   <- run once to bootstrap
  builder_linux/   steamcmd (Linux)
  builder_osx/     steamcmd (macOS)
  content/         <- your final, runnable build goes here (the files players get)
  output/          build logs + chunk cache (safe to delete; speeds up re-uploads)
  scripts/         <- your *.vdf build scripts live here
```

### 2. 最小应用构建脚本——`app_build_1000.vdf`

```text
// AppID 1000 with one depot (1001): upload everything under ../content recursively.
// VDF is Valve KeyValues: "key" "value", braces for nesting. Adjust IDs to your app.
"AppBuild"
{
    "AppID"       "1000"                 // your App ID
    "Desc"        "1.0.0 launch build"   // internal only; visible in Your Builds

    "ContentRoot" "..\content\"          // root of files to upload (relative to this file)
    "BuildOutput" "..\output\"           // logs + chunk cache

    "Depots"
    {
        "1001"                           // your Depot ID
        {
            "FileMapping"
            {
                "LocalPath"  "*"         // all files from ContentRoot
                "DepotPath"  "."         // mapped to the depot root
                "recursive"  "1"         // include subfolders
            }
        }
    }
}
```

### 3. 上传构建（Windows；在其他平台上替换相应的 builder）

```bat
REM Run from the SDK. Bootstrap once, then build. Use a build account, not your admin login.
tools\ContentBuilder\builder\steamcmd.exe ^
  +login <build_account> <password> ^
  +run_app_build ..\scripts\app_build_1000.vdf ^
  +quit
```

```text
What happens: steamcmd self-updates -> logs in -> for each depot, hashes files into ~1 MB
chunks -> uploads only NEW chunks -> writes a depot manifest -> finishes with a global
BuildID. The build is NOT live yet; set it live per the workflow above.
```

### 4. 使用预览构建安全迭代（不上传任何内容）

```text
// Add to the AppBuild block to validate file mappings without uploading:
"Preview" "1"     // outputs logs + a file manifest into BuildOutput only
// And to auto-set live on a BETA branch after a successful build (never 'default'):
"SetLive" "beta-qa"
```

## 常见陷阱

- **`default` 分支无法自动设为上线版本。**`SetLive` 仅适用于 *beta* 分支；你必须在 App Admin 中
  手动将默认（客户）构建设为上线版本。发布计划需考虑这一点。
- **商店页面必须先于构建获批。**在商店展示内容提交之前，无法提交构建审核；两者都必须通过，
  且 Coming Soon 必须持续约 2 周。
- **游戏绝不会自动发布。**即使获批，也必须由人在选定时刻点击 **Release App**。
- **Mac/Linux 未安装任何内容。**几乎总是因为 package 中没有特定于操作系统的 depot。
  在 *Associated Packages & DLC* 中将所有 depot 添加到 package。
- **未发布的应用配置。**“Failed to get application info” / 构建错误通常表示 depot、启动选项或
  App ID 配置从未被**发布**。
- **构建出现 `status = 6`。**构建账户没有 App ID 的权限，或 `ContentRoot`/`LocalPath`
  指向错误的（空）路径。
- **提交登录令牌。**`config.vdf` Steam Guard 令牌和账户密码都是机密。不要将其放入仓库；
  使用参考资料中的 CI 工作流。
- **已发布应用的安全延迟。**更改构建账户的电子邮箱/电话号码，会导致你在为*已发布*应用设置
  上线构建前必须等待 **3 天**——不要在发布前重新配置账户。

## 参考资料

- 有关高级多 depot/多平台构建脚本、`FileExclusion`/`FileProperties`、beta 分支设置、
  CI/CD 登录令牌工作流和 SteamPipe 故障排除表，请阅读
  `references/steampipe-build-scripts.md`。
- 主要文档：Steamworks “Uploading to Steam”（`partner.steamgames.com/doc/sdk/uploading`）、
  “Release Process”（`/doc/store/releasing`）、“Branches (Betas)”（`/doc/store/application/branches`）、
  “Depots”（`/doc/store/application/depots`）。

## 相关 skill

- `itch-publish` — 使用 `butler` 将同一游戏发布到 itch.io（通常与 Steam 一同进行）。
- `game-jam` / `prototype-fast` — 同一项目生命周期中更早的阶段。
