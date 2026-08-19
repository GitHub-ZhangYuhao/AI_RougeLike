---
name: router
description: >
  将任何游戏开发请求路由到正确的专业 skill：检测引擎
  （Godot、Unity、Unreal、Bevy、Phaser、PixiJS、three.js、LÖVE、pygame、Roblox）和任务，
  然后在行动前读取选定的 skill。适用于制作游戏或判断应使用哪个 skill——涵盖玩家、关卡、
  敌人、着色器、美术指导、精灵、图块、纹理、3D 资源、UI/UX、摄像机、游戏手感、物理、输入、
  音频、保存、多人游戏、AI、对话、程序化生成或性能，涵盖类型（platformer、
  roguelike、RPG、FPS、tower-defense、card game、visual novel、survival-crafting、puzzle），
  以及发布（game jam、Steam、itch）。不确定该使用哪个游戏开发 skill 时从这里开始。
---

# 主路由器——游戏开发 Skill 分发器

游戏开发工作的入口。它通过项目指纹选出**一个**引擎，根据请求对任务分类，给出**最小**的
专业 skill 集合，并要求你在行动前阅读它们。它负责**分发和组合**——不会重新讲授引擎 API。

## 使用时机

- 在**任何游戏开发请求开始时**使用——构建或调试游戏、关卡、玩家、敌人、着色器、UI、
  保存系统、多人游戏、输入、音频、AI、对话、程序化内容或视觉资源集——以决定加载哪些 skill。
- 当用户指定引擎或类型、说“make a game”，或询问“which skill should I use?”时使用。

**不应使用的情况：**一旦已加载正确的 skill，且任务明确属于其范围，就应依据该 skill 工作——
不要每一轮都重新运行路由器。仅当任务**转向**新引擎或关注点时才重新路由（路由器步骤 6）。

## 路由算法

1. **检测引擎和版本**——项目指纹 → 最多一个引擎 skill 集（或“unknown”），然后读取项目的版本来源。§1。
2. **任务分类**——措辞 → 领域 + 最多一个类型 + 工作流。§2。
3. **解析**——最小集合：引擎 skill + 领域 + 类型 + 工作流。§3。
4. **读取（渐进披露）**——仅打开选定的 `SKILL.md` 正文；只在需要时读取 `references/`。§4。
5. **组合**——顺序：引擎基础 → 领域概念 → 类型衔接 → 工作流。§5。
6. **回退**——引擎未知或没有匹配的 skill → 提问或默认使用 Godot；说明任何覆盖缺口。§6。

---

## 1. 引擎检测（项目指纹）

扫描置信度最高的信号；**只选择一个**引擎。首次匹配后即停止。

| # | 引擎 | 主要信号 | Skill 集根目录 |
|:-:|--------|----------------|----------------|
| 1 | Godot | `project.godot` | `skills/godot/` |
| 2 | Unreal | `*.uproject` | `skills/unreal/` |
| 3 | Unity | `Assets/` **and** `ProjectSettings/ProjectVersion.txt` | `skills/unity/` |
| 4 | Bevy | `Cargo.toml` with a `bevy` dependency | `skills/other-engines/bevy-ecs/` |
| 5 | Phaser | `package.json` dep `phaser` | `skills/web-engines/phaser-*` |
| 6 | PixiJS | `package.json` dep `pixi.js` | `skills/web-engines/pixijs-rendering/` |
| 7 | three.js | `package.json` dep `three` | `skills/web-engines/threejs-*` |
| 8 | LÖVE | `conf.lua` / `main.lua` calling `love.*` | `skills/other-engines/love2d-core/` |
| 9 | pygame | `*.py` with `import pygame` | `skills/other-engines/pygame-core/` |
| 10 | Roblox | `*.rbxl(x)` / `*.project.json` (Rojo) | `skills/other-engines/roblox-*` |

有关次要信号、Godot-C#/Unity/Bevy 和多 Web 引擎消歧规则、monorepo 以及纯文本引擎提及，
请阅读 `references/engine-detection.md`。

识别引擎后，在选择 API 前从项目元数据或依赖锁定文件中读取其版本。除非明确要求迁移，
现有项目应保持其锁定版本；目录基线仅适用于新项目。确切的版本来源见检测参考资料和
`../docs/VERSION-SUPPORT.md`。

## 2. 任务分类（措辞 → 类别）

确定引擎后，读取请求中的任务信号（三个**可叠加**类别）：

- **领域**（跨引擎概念）：`create-game-assets`、`game-ai`、`procedural-gen`、`dialogue-systems`、
  `save-systems`、`audio-design`、`shader-programming`、`physics-tuning`、`level-design`、
  `input-systems`、`game-feel`、`camera-systems`、`game-ui-ux`、`performance-optimization`。
  由概念词（"sprite sheet"、"art direction"、"texture"、"pathfinding"、
  "save slots"、"fragment shader"、"screen shake"、"camera follow"、"HUD/menu"、
  "optimize/low FPS"）触发。
- **类型**（完整游戏模板）：`platformer`、`roguelike`、`rpg`、`fps-shooter`、
  `tower-defense`、`card-game`、`visual-novel`、`survival-crafting`、`puzzle`。
  由类型词（"make a roguelike"、"deckbuilder"）触发。
- **工作流**（流程/发布）：`game-jam`、`prototype-fast`、`steam-publish`、
  `itch-publish`。由流程词（"publish on Steam"、"vertical slice"）触发。

文件信号可进一步提高准确度：`*.yarn`/`*.ink` → `dialogue-systems`/`visual-novel`；`steam_appid.txt`
→ `steam-publish`；`*.inputactions` → `unity-input-system`。

## 3. 路由表（任务 → 类别 → skill）

### 3a. 引擎 skill——读取与检测到的引擎和子任务匹配的 skill

- **Godot**（`skills/godot/`）：语言 `godot-gdscript` / `godot-csharp`；结构
  `godot-nodes-scenes`、`godot-signals-groups`；2D `godot-2d-movement`、`godot-tilemap`；3D
  `godot-3d-essentials`；物理 `godot-physics`；UI `godot-ui-control`；动画
  `godot-animation`；着色器 `godot-shaders`；数据 `godot-resources`；音频 `godot-audio`；
  网络代码 `godot-multiplayer`；发布 `godot-export`。
- **Unity**（`skills/unity/`）：脚本 `unity-csharp-scripting`；输入 `unity-input-system`；
  物理 `unity-physics`；动画 `unity-animation`；数据 `unity-scriptableobjects`；2D
  `unity-tilemap-2d`；AI 导航 `unity-navmesh`；发布 `unity-build-pipeline`。
- **Unreal**（`skills/unreal/`）：可视化脚本 `unreal-blueprints`；C++ 游戏逻辑
  `unreal-cpp-gameplay`；输入 `unreal-enhanced-input`；AI `unreal-behavior-trees`；VFX
  `unreal-niagara`；发布 `unreal-packaging`。
- **Web**（`skills/web-engines/`）：`phaser-core`、`phaser-arcade-physics`；`pixijs-rendering`；
  `threejs-scene-setup`、`threejs-gltf-loading`、`threejs-materials-lighting`。
- **其他**（`skills/other-engines/`）：`bevy-ecs`、`pygame-core`、`love2d-core`、`roblox-luau`、
  `roblox-datastores`。

### 3b. 领域——与引擎 skill **一起**加载（概念 ↔ 引擎 API）

| 概念（`says:`） | 领域 skill | 搭配（引擎 API） |
|-------------------|------------------|-------------------------|
| art direction, game assets, sprites, tilesets, textures, icons, 3D props | `create-game-assets` | 引擎导入器/渲染 skill；可用时使用 `imagegen` |
| enemy AI, behavior tree, pathfinding, steering | `game-ai` | `unity-navmesh` / `unreal-behavior-trees` / Godot nav |
| procedural, noise, seed, dungeon generator | `procedural-gen` | 引擎 tilemap/grid skill |
| dialogue, Yarn, Ink, conversation tree | `dialogue-systems` | 引擎 UI skill |
| save/load, slots, persistence | `save-systems` | `roblox-datastores` / 引擎 IO |
| adaptive music, mixer, ducking, SFX | `audio-design` | `godot-audio` / Unity AudioMixer |
| shader, fragment, dissolve/outline | `shader-programming` | `godot-shaders` / 引擎材质 |
| jitter, tunneling, fixed timestep | `physics-tuning` | `godot-physics` / `unity-physics` |
| whitebox, blockout, tile layout, pacing | `level-design` | `godot-tilemap` / `unity-tilemap-2d` |
| rebind, gamepad, input buffering | `input-systems` | `unity-input-system` / `unreal-enhanced-input` / Godot InputMap |
| screen shake, hit-stop, juice, squash & stretch, "make it punchy" | `game-feel` | 引擎 animation/tween + `camera-systems`（shake） |
| camera follow, deadzone, look-ahead, orbit, first-person | `camera-systems` | `godot-2d-movement` / `godot-3d-essentials` / Cinemachine |
| HUD, menu, UI layout, scaling, safe area, focus nav | `game-ui-ux` | `godot-ui-control` / Unity UI（UGUI/UI Toolkit） |
| low FPS, optimize, draw calls, GC spike, pooling, profiler | `performance-optimization` | 引擎 profiler + `physics-tuning` |

### 3c. 类型——**组合**引擎 + 领域（将 `*` 绑定到检测到的引擎）

| 类型（`says:`） | 组合内容 |
|-----------------|----------|
| platformer, jump, double jump | `godot-2d-movement`（或引擎物理）+ `godot-tilemap`/`unity-tilemap-2d` + `level-design` + `camera-systems` + `game-feel` |
| roguelike, procedural dungeon, permadeath | `procedural-gen` + `godot-tilemap`/`unity-tilemap-2d` + `game-ai` + `save-systems` + `game-feel` |
| RPG, stats, inventory, quests | `godot-resources`/`unity-scriptableobjects` + `dialogue-systems` + `save-systems` + `game-ui-ux` |
| FPS, first-person, hitscan | `godot-3d-essentials`/`unreal-cpp-gameplay` + `input-systems` + `game-ai` + `camera-systems` + `game-feel` |
| tower defense, waves, lanes | `game-ai` + 引擎移动 + `level-design` + `game-ui-ux` |
| card game, deckbuilder, TCG | `godot-resources`/`unity-scriptableobjects` + `game-ui-ux`（+ 引擎 UI） |
| visual novel, branching story | `dialogue-systems` + `save-systems` + `game-ui-ux` |
| survival, crafting, gathering | `save-systems` + `godot-resources`/`unity-scriptableobjects` + `procedural-gen` + `game-ui-ux` |
| puzzle, match-3, grid logic | `godot-tilemap`/`unity-tilemap-2d` + `level-design` + `game-feel` |

### 3d. 工作流——与引擎无关的流程和发布

`game-jam`（jam、48-hour、Ludum Dare/GMTK）· `prototype-fast`（vertical slice、MVP、greybox）·
`steam-publish`（Steam、Steamworks、depot；`steam_appid.txt`）· `itch-publish`（itch.io、butler；
`.itch.toml`）。

有关详尽的逐 skill 触发项列表和所有引擎绑定，请阅读
`references/routing-table.md`。

## 4. 读取协议（渐进披露）

1. **预加载：**上下文中仅包含各 skill 的 `name` + `description`。根据这些内容和指纹作出决定——
   **不要**预先读取正文。
2. **选中时：**读取**每个选定**的 `skills/<category>/<name>/SKILL.md` 正文——且仅限这些文件。
   切勿批量加载整个类别。
3. **按需：**仅在子任务需要相应深度时读取 skill 自带的 `references/` 文件
   （skill 正文会说明何时需要）。
4. **转向时重新路由：**如果任务发生变化（movement → saving），选择并读取新相关的 skill，
   而不是让所有内容一直保持加载。

说明你加载了什么及其原因，例如：*“检测到 Godot（`project.godot`）。为控制器加载
`godot-2d-movement`，为跳跃手感加载 `platformer`；如果你需要 coyote-time/buffering，
将打开 platformer skill 的 `feel-tuning.md` 参考资料。”*

## 5. 组合规则

- **一个引擎集，可叠加概念。**只使用一个引擎 skill 集；添加任务所需的领域，并且通常
  **最多选择一个**类型。工作流独立附加。
- **顺序：**引擎基础 → 领域概念 → 类型编排 → 工作流。对于资源制作，先批准视觉目标，
  再生成一个系列，最后完成引擎导入设置和上下文内截图。
- **重叠时的职责归属：****引擎** skill 负责 API/语法；**领域** skill 负责可移植概念/算法，
  并将代码交给引擎 skill；**类型** skill 负责结构/衔接，通过链接引用而不是重新讲授基础要素。
- **交接：**当某类型的 `composes` 指定 `*-2d-movement` 之类的槽位时，将其绑定到检测到的引擎。
  如果该引擎缺少对应 skill，请参见 §6 和 `references/routing-table.md`（“Binding gaps”）。

## 6. 未知引擎与无 skill 时的回退

**引擎未知**（无指纹，也未指定引擎）：

1. 检查请求中是否有纯文本引擎名称（"in Unity"、"using Phaser"）。如果找到，就采用它。
2. 如果任务是纯概念/类型/工作流问题，直接路由到与引擎无关的领域/类型/工作流 skill——无需引擎
   （"what's a good save format?" → `save-systems`）。
3. 仅当引擎选择确实阻碍回答时，提出**一个**有针对性的问题（"Which engine — Godot, Unity,
   Unreal, or a web/other engine?"）。如果用户没有偏好而任务需要引擎，**默认使用 Godot**
   （这里覆盖最完整的引擎），并明确说明。
4. 切勿虚构引擎或凭猜测加载引擎 skill。

**引擎已知但没有 skill 覆盖子任务：**加载最接近的引擎 skill 和相关领域，并明确**说明缺口**
（例如 "no dedicated Unity 2D-movement skill; using `unity-csharp-scripting` +
`unity-physics`"）。切勿编造 skill 名称。

**类型冲突/多个类型：**根据措辞选择主导类型；提及次要类型，并在用户确认后再加载。

## 完整示例

| 请求 | 检测到的引擎 | 加载的 skill（按顺序） |
|---------|-----------------|--------------------------|
| "add a double jump to my Godot player" | Godot（`project.godot`） | `godot-2d-movement` → `platformer` |
| "make an inventory for my Unity RPG" | Unity（`Assets/`+`ProjectSettings/`） | `unity-scriptableobjects` → `rpg` → `save-systems` |
| "procedural dungeon roguelike in Godot" | Godot | `godot-tilemap` → `procedural-gen` → `roguelike` |
| "branching dialogue from a `.yarn` file" | （无需引擎） | `dialogue-systems`（+ 检测到引擎时使用引擎 UI skill） |
| "how do I design save slots with migration?" | （无） | 仅 `save-systems` |
| "publish my game on itch with butler" | （任意/无） | 仅 `itch-publish` |
| "I want to make a game but don't know what to use" | unknown → 提问，默认 Godot | 路由器只问一次；然后例如 `godot-nodes-scenes` |
| "make hits feel punchy in my Godot game" | Godot（`project.godot`） | `game-feel`（+ 用于 shake 的 `camera-systems`） |
| "the camera should follow my player smoothly" | （检测到的引擎） | `camera-systems`（+ 引擎 movement skill） |
| "my Unity game drops to 30 FPS, optimize it" | Unity（`Assets/`+`ProjectSettings/`） | `performance-optimization`（先 profile）→ 引擎 skill |
| "make a cohesive pixel-art player and enemy set" | （检测到的引擎） | `create-game-assets` → 相关引擎 import/rendering skill |

## 参考资料

- 完整的引擎指纹、次要信号和消歧：`references/engine-detection.md`。
- 详尽的逐 skill 触发词、引擎绑定和绑定缺口：`references/routing-table.md`。
