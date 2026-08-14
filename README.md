# 暗夜幸存者 · 类吸血鬼幸存者 MVP

纯 HTML5 Canvas + 原生 JavaScript（ES Modules），零依赖、零构建，浏览器即开即玩。

## 快速开始

```powershell
node tools/serve.js
# 浏览器打开 http://localhost:5173
```

## Godot MCP（Codex）

Godot 移植工程位于 `GameProject/`，使用 Godot 4.7.1。Codex 通过本地 stdio 启动
[`godot-mcp-server`](https://github.com/tomyud1/godot-mcp)，服务端再通过
`ws://127.0.0.1:6505` 连接 Godot 编辑器插件。

### 前置条件

- 已安装 Node.js 和 npm。
- 已用 Godot 4.x 打开 `GameProject/project.godot`。
- MCP 仅监听本机，不需要 API Key。

### 安装并启用 Godot 插件

1. 在 Godot 编辑器打开 **AssetLib**，搜索 `Godot AI Assistant tools MCP` 并安装。
2. 打开 **Project → Project Settings → Plugins**，启用 **Godot MCP**。
3. 重启 Godot 项目。插件会安装到 `GameProject/addons/godot_mcp/`。

`GameProject/AGENTS.md` 默认禁止引入第三方 addon；提交插件前必须先明确将 Godot MCP
列为开发工具例外。若只供本机使用，应避免把插件目录混入玩法代码提交。

### 配置 Codex MCP

本仓库通过项目级 `.codex/config.toml` 配置 Godot MCP：

```toml
[mcp_servers.godot]
command = "cmd"
args = ["/c", "npx", "-y", "godot-mcp-server@0.5.0"]
```

Codex CLI 和 IDE 扩展只会在仓库被标记为 trusted 时加载项目级 `.codex/config.toml`。
不要执行 `codex mcp add godot ...`，该命令会写入用户级 `~/.codex/config.toml`，导致所有
工作区都加载 Godot MCP。

固定使用 `0.5.0`，避免 `latest` 在未验证时自动升级。配置后从本仓库目录启动或重启
Codex 会话，并保持 Godot 编辑器及插件处于运行状态。

### 验证连接

```powershell
codex mcp get godot
codex mcp list
```

Godot 编辑器右上角应显示绿色的 `MCP Connected`。如果 Codex 已配置但编辑器未连接，请依次检查：

1. Godot MCP 插件是否已启用；
2. Godot 项目是否已在插件启用后重启；
3. 本机端口 `6505` 是否被其他进程占用；
4. Codex 是否已在新增配置后重启。

此 MCP 的编辑操作可能直接保存文件且不提供 Undo。调用前后应检查 `git diff`；纯逻辑回归仍使用
Godot headless smoke，而不是用 MCP 替代自动化测试。

如需移除项目配置，删除 `.codex/config.toml` 中的 `[mcp_servers.godot]` 表即可。

## Godot 美术资源配置

完整状态台账见 [`GameProject/ART_ASSET_CONFIG.md`](./GameProject/ART_ASSET_CONFIG.md)，其中按已配置、待修订、未配置和占位符分类记录所有资源。

Godot 工程只引用 `GameProject/` 内的 `res://` 资源。`ArtAsset/` 保存源素材，定稿后复制到
`GameProject/assets/`，并将 Godot 生成的 `.import` 文件与素材一起提交。

### 玩家序列帧

| 用途 | 配置位置 |
| --- | --- |
| 源素材 | `ArtAsset/CharacterAnimation/Player/` |
| Godot 运行时素材 | `GameProject/assets/sprites/player/` |
| 图集切帧、动画名和 FPS | `GameProject/scenes/game/player_sprite_frames.gd` |
| 状态、方向、缩放和脚底偏移 | `GameProject/scenes/game/player_view.gd` |
| 玩家表现节点 | `GameProject/scenes/game/player_view.tscn` |
| 八方向动画预览 | `GameProject/scenes/game/player_animation_preview.tscn` |

当前约定：

- `idle.png` 是 6×6 图集，共 36 帧；`IDLE_FPS` 控制播放速度。
- 移动动画由同名 PNG + JSON 组成，JSON 的 `uv_min_* / uv_max_*` 乘实际 PNG 尺寸得到帧区域。
- `MOVE_ANIMATIONS` 维护逻辑动画名到素材名的映射；`MOVE_FPS` 控制移动播放速度。
- `WALK_SCALE`、`IDLE_SCALE` 和 `SPRITE_FOOT_OFFSET` 控制显示尺寸与脚底对齐。
- 当前玩家画面异常已确认来自源序列帧质量或帧间连贯性，不是方向映射或状态机缺陷。替换
  `assets/sprites/player/` 中对应 PNG/JSON 后即可继续验证。

在 Godot 中打开 `player_animation_preview.tscn`，按 `F6` 可同时查看 Idle 和全部移动方向。

### 地形贴图与节点式材质

| 用途 | 配置位置 |
| --- | --- |
| 源贴图 | `ArtAsset/Image/Environment/GroundTextures/StyleAnchors/v07_soft_cartoon_ground_textures/final/` |
| Godot 运行时贴图 | `GameProject/assets/ground_*.png` |
| VisualShader 节点图 | `GameProject/assets/ground_visual_shader.tres` |
| ShaderMaterial 参数实例 | `GameProject/assets/ground_visual_material.tres` |
| 正式草甸关卡 | `GameProject/scenes/game/meadow_level.tscn` |
| 正式关卡入口 | `GameProject/scenes/main.tscn` |
| 地图边界与碰撞 | `GameProject/logic/level_geometry.gd` |
| 独立材质预览关卡 | `GameProject/scenes/game/art_ground_preview.tscn` |
| 预览相机控制 | `GameProject/scenes/game/art_ground_preview.gd` |
| 源贴图复制工具 | `GameProject/tools/import_ground_assets.gd` |
| VisualShader 生成工具 | `GameProject/tools/create_ground_visual_shader.gd` |

材质参数：

- `terrain_scale`：贴图采样缩放。
- `macro_scale`：宏观区域分布密度。
- `dirt_amount`：泥地区域比例。
- `stone_amount`：石地区域比例。
- `terrain_tint`：整体色调。
- `tint_strength`：色调混合强度。

`meadow_level.tscn` 已挂入 `main.tscn`，是当前主游戏正式使用的 4096×4096 草甸关卡。玩家、敌人、
弹道、相机、刷怪点和任务点统一受 `level_geometry.gd` 的确定性地图边界约束；玩家额外保留视觉安全边距。
地面贴图中的石块属于可行走的地表细节，不生成物理碰撞，后续独立树木、岩石等场景组件需在逻辑层登记障碍几何。

如需单独调整材质，仍可打开 `art_ground_preview.tscn` 并按 `F6`；方向键移动相机，滚轮缩放，`R` 重置。

注意：Godot 4.7.1 的 `Polygon2D` 未绑定自身 `texture` 时，CanvasItem Shader 收到的 UV 会全部为
`(0, 0)`，画面会退化成单色。`Ground.texture` 必须保留，UV 也必须按 2048×2048 基础贴图的
像素坐标配置。不要将其改回 0–1。

`create_ground_visual_shader.gd` 会重新生成并覆盖 VisualShader 和材质实例。手工修改节点图后不要再次
运行该工具，除非明确希望恢复生成版本。

### 临时占位符表现

缺失正式美术的玩法对象集中由 `GameProject/scenes/game/placeholder_world_view.gd` 绘制，不在逻辑层保存
表现状态。当前覆盖七类敌人、玩家/敌方弹道、经验宝石、血包与稀有掉落、死灵召唤物、披风范围、
玉环、丹火轨迹/炉域、任务标记和通用联动特效。敌人使用不同轮廓、颜色和单字标签，并显示必要的
血条与状态标识。

正式资源到位后按类型逐项替换 PlaceholderWorld 中对应绘制函数；在正式视图完成前保留占位实现，
确保玩法机制始终可测试、可识别。

## 操作

- WASD / 方向键：移动
- 武器全自动攻击，无需手动操作
- 选卡（开局 / 升级时弹出）：**鼠标点击卡牌** 或 **按数字键 1-9**
- 死亡后按 R 重新开始
- **F2 调试工具**：打开面板时默认暂停；可调经验/人物属性、武器等级、怪物倍率、刷怪与波次
- 保存的调试配置不会自动加载；控制台可通过 `__game.debug` 调用同一套接口

## 当前内容

### Step 1 · 核心循环

- 固定时间步长 game loop（逻辑 60Hz，渲染每帧）+ 相机平滑跟随
- 玩家移动、受击无敌帧、死亡判定
- 敌人在屏幕外生成并追击玩家；难度以波次为主增长（投放量、同屏上限、血量、伤害、速度）
- 敌人受击白闪 / 血条、玩家受击震屏
- 调试入口：浏览器控制台 `__game` 可查看/修改游戏状态

### Step 2 · 卡牌 / 经验 / 宝石（肉鸽成长循环）

- 敌人死亡掉落经验宝石，靠近自动吸附拾取；宝石价值随游戏时长提升
- 升级弹出「三选一」卡牌界面（选卡期间世界暂停）；一次升多级会连锁选卡
- 开局从全部 6 张武器卡中选 1 张；**武器槽上限 3**，走配置 `CONFIG.cards.maxWeaponSlots`（后续可扩展到 5，不写死）
- **武器卡（6 种，各 6 级，重复抽到同名卡 = 升级）**：
  - ⚔️ 道剑：Lv1 近战挥砍，Lv2 起转为远程贯穿飞剑
  - 🔥 炽热披风：持续灼烧附近敌人，并周期释放震荡冲击
  - ⚡ 雷符咒：单发雷电弹道，高阶解锁引雷与闪电链
  - 🔥 丹火：移动铺设火轨，Lv4 起闭环生成丹炉火域，满级开炉形成九转高温火域
  - 💍 玉环：围绕玩家旋转的玉环，触碰造成伤害
  - 💀 死灵法杖：周期性召唤仆从。仆从**无法被击杀**（无血条），但有固定存活时间；每个召唤槽位有独立内置 CD；不会离开玩家太远（leash）
- **属性卡（6 种，可重复抽取叠加，每种上限 5 层）**：
  - 伤害提升（每层 +15%）
  - 护甲提升（每层 +15；`护甲/(护甲+100)`，减伤上限 50%）
  - 拾取范围（每层 +50px）
  - 经验倍率（每层 +15%）
  - 血量提升（每层最大生命 +20，并立即恢复 20）
  - 移动速度（每层 +6%）
- HUD：顶部全宽经验条、等级、血条、武器槽（图标 + 等级）、计时、击杀数
- **定时波次系统**：每波持续 90 秒，普通波按倒计时推进且敌人可跨波保留；计划投放量随波次提高，每 3 波保证精英，每 5 波进入 Boss 波；Boss 超时后停止投放并等待击败
- **精英怪显示与奖励**：金色外环、精英标签和常驻血条；死亡必掉一件可拾取的稀有物品
- **Boss「暗夜领主」**：独立 Boss 血条、蓄力提示、环形弹幕和半血狂暴；击败后掉落两件稀有物品
- **稀有物品**：战意符石、血玉、聚灵核心、悟道残卷、疾风羽，提供永久局内增益并显示拾取提示
- **经验吸附优化**：默认基础吸附范围为 180px，可通过拾取范围属性提升；宝石一旦进入范围便锁定玩家，不会因原始散射速度或越界被甩走

## 自检

```powershell
node tools/headless-smoke.mjs
# 无头冒烟测试：开局选卡 / 移动 / 60 秒战斗与自动选卡 / 鼠标选卡生效 /
# 属性数值与护甲 / 武器质变 / 丹火闭环与开炉 / 仆从上限 / 敌人波次成长 / 精英掉落 / Boss / 经验吸附 / 死亡与重开
```

## 项目结构

```
index.html            入口页面
js/
  main.js             启动、RAF 循环、固定时间步长
  game.js             游戏状态机（opening/playing/choice/dead）+ 碰撞 + 渲染分层
  config.js           全部平衡性数值
  input.js            键盘 + 鼠标输入
  camera.js           相机跟随
  player.js           玩家
  enemy.js            敌人（含防重叠推挤）
  spawner.js          屏外生成位置、节奏与同屏上限
  cards.js            卡牌定义（6 武器 + 6 属性）、卡池生成、属性乘数
  ui-cards.js         选卡界面（布局 + 渲染，鼠标命中共用布局）
  weapons/            6 种武器的独立实现
  enemies/            普通、特殊、精英与 Boss 敌人
  systems/waves.js    90 秒定时波次、精英波、Boss 超时与检查点休整
  rare-items.js       稀有物品定义、拾取效果与绘制
  projectile.js       子弹
  gems.js             经验宝石（吸附 / 拾取 / 档位）
  hud.js              HUD（经验条 / 武器槽）与死亡界面
tools/
  serve.js            静态服务器
  headless-smoke.mjs  无头冒烟测试
```

## 迭代路线

- [x] Step 1：核心循环（移动 / 追击 / 自动攻击 / 死亡重开）
- [x] Step 2：经验宝石 + 卡牌系统（6 武器卡 + 6 属性卡、武器槽、鼠标/按键选卡）
- [ ] Step 3（部分完成）：武器 Lv1–6、精英怪已完成；武器进化组合与被动道具待做
- [ ] Step 4（部分完成）：定时波次与 Boss 已完成；宝箱系统待做
- [ ] Step 5：金币、局外永久成长（meta progression）
- [ ] Step 6：精灵图 / 音效 / 特效、对象池等性能优化

## 设计文档

- [DESIGN.md](./DESIGN.md)：开发进度记录 + 武器升级 6 级路线方案（原案评估 / 三子 Agent 方案 / 最终推荐选择 / 待拍板项）
