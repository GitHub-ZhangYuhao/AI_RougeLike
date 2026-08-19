---
name: create-game-assets
description: 规划、生成、溯源、标准化并验证连贯的视觉游戏资产。适用于艺术指导、风格圣经、精灵图、瓦片集、背景、UI 美术、图标、纹理、概念设计或 3D 资产简报。
---

# 创建游戏资产

将游戏的视觉意图转化为一致且引擎就绪的资产集合。将图像生成视为受控流水线中的一个生产工具，而非证明某项资产可发布的依据。

## 核心工作流

1. **先审查，后创作。** 查找现有的截图、概念图、精灵、模型、字体、导入设置、相机构图、目标分辨率和命名规范。除非用户要求重新设计，否则保持连贯的现有方向。
2. **锁定技术框架。** 记录引擎、2D/3D、相机视角、原生显示尺寸、资产尺寸、世界比例、透明度、调色板、过滤方式、动画帧数、纹理预算以及目标平台。使用 `assets/art-direction-brief.md` 作为可复制的简报模板。
3. 命名视觉系统。定义形状语言、剪影优先级、明暗结构、色板角色、材质、光照、细节密度、边缘处理和运动特征。使用具体的视觉属性；不要以在世艺术家的名字替代美术方向。
4. 制作资产清单。复制`assets/asset-manifest.json`，然后列出所有必需的资产、状态、变体、大小、枢轴点、碰撞角色、源、许可证和批准状态。将生产用资产与可丢弃的灰盒占位符分开。
5. **批准一个视觉目标。** 在制作全套内容之前，创建或选择一个具有代表性的英雄资产或小风格板。在实际游戏比例和游戏背景背景下对其进行评估。如果用户将选择权委托给了你，请选择最可行的方向并记录该决定，而不是进行阻碍。
6. 将相关资产生成家族。复用已批准的作为编辑/参考输入。保持调色板、视图、比例、光照、轮廓和纹理密度不变量。生成小型连贯批次；避免无关的单一提示导致偏离。
7. **确定性地归一化。** 使用普通图像/数字摄影测量工具进行裁剪、缩放、锚点设置、切片、命名、压缩及透明度检查。切勿在未检验的情况下信任生成的网格、透明通道、接缝、枢轴点、拓扑结构或尺寸。请使用内置脚本执行光栅质量检查和联系表生成。
8. 使用引擎原生设置进行导入。有意识地配置过滤、多级纹理（mipmaps）、像素/单位或世界比例、颜色空间、压缩方式、精灵切片、纹理类型、材质和碰撞检测。在编辑引擎文件前，先阅读相关的引擎技能文档。
9. **在上下文中验证。** 以原生分辨率检查接触表和实际游戏。检查轮廓、比例、动画稳定性、接缝、可读性、调色板、碰撞适配、内存占用和压缩伪影。迭代源资产，而不仅仅是运行时补偿措施。
10. **记录来源信息。** 在清单旁保留源网址/工具、许可证或生成说明、编辑历史以及限制。当管道支持时，请保存嵌入的来源元数据。

## 选择制作路径

| 需求 | 默认路径 |
|------|--------------|
| 现有资产需要受控变更 | 编辑原始/参考内容；说明哪些必须保持不变 |
| 新 2D 视觉家族 | 批准种子 → 生成/来源家族 → 标准化 → 预览 → 导入 |
| 真正的像素艺术 | 使用生成作品作为草稿；用像素工具强制网格、调色板、色块和帧 |
| 可平铺表面或瓦片集 | 制作一个小型系列；修复接缝；批准前测试重复平铺的 3×3 网格 |
| 用户界面美术或图标 | 保持文本和交互代码的原生性；对于简单的几何符号，优先使用 SVG/矢量图 |
| 3D 模型或材质 | 以概念为参考；在数字内容创作软件中制作/清理拓扑、UV、比例、枢轴点和 LOD（多细节层次）并验证其正确性。 |
| 没有可用的生成/编辑工具 | 构建简报和清单；获取授权资产或保留明确的灰盒占位符 |
| 音频资产 | 实现并混合路由至`audio-design`，同时在清单中跟踪来源/许可证信息 |

## 图像生成交接

当安装了具备能力的图像生成或编辑工具时，用于实时视觉创作。如果工作区暴露了`imagegen` 技能，请阅读并遵循它进行实际的生成/编辑调用；该技能拥有游戏艺术简报、约束条件、标准化和验收关卡的所有权。

从这些模块构建提示词：

```text
ROLE/PURPOSE: production asset for [gameplay role]
SUBJECT: [specific object/character and action]
VIEW: [orthographic/top-down/side/three-quarter], [camera and facing]
ART DIRECTION: [shape language], [palette roles], [materials], [edge treatment]
GAME-SCALE READ: [silhouette and focal details that must survive at WxH]
TECHNICAL OUTPUT: [dimensions/aspect], [transparent or scene background], [frame/slot count]
LOCKS: preserve [identity, proportions, palette, costume, lighting, line weight]
EXCLUDE: text, labels, mockup frames, scenery, duplicate objects, cropped edges, signatures
```
在编辑中，需明确标注哪些内容已更改、哪些保持不变。若工具原生支持该功能，请请求其透明输出；随后务必验证 Alpha 通道——仅凭提示词无法确保透明度。

## 栅格质量检查方案

审查约束条件并生成机器可读的报告：

```bash
python scripts/asset_report.py assets/player-idle.png \
  --expect-size 64x64 --require-alpha --max-colors 48 --json
```
在棋盘格上构建最近邻接触表：

```bash
python scripts/build_preview_sheet.py output/player/*.png \
  --out output/player-preview.png --columns 4 --cell-size 192
```
脚本路径相对于此技能目录，或首先解析已安装的技能路径。两个脚本都需要 Python 3.10+ 和 Pillow。如果尚未可用，请使用 `python -m pip install -r scripts/requirements.txt` 安装唯一的依赖项。

## 质量门槛

- **Cohesion（整体性）**：相关资产共享调色板角色、线条/边缘处理方式、视角、光照方向、比例尺和细节密度。
- **Gameplay read（游戏可读性）**：剪影与状态变化在原生分辨率下保持清晰，且在运动中和真实背景上依然可辨。
- **技术适配度**：精确的尺寸与帧率、可用的透明通道、稳定的锚点/枢轴、正确的色彩空间与滤镜处理、无裁剪内容、无意外的标签或未烘焙的模拟 Chrome 元素。
- **Animation（动画表现力）**：身份特征、体积感、比例关系、服装样式、朝向和基线不发生漂移；时间感和预期在引擎内预览中清晰可读。
- **Tiles/backgrounds（瓦片/背景处理）**：所需边缘无缝拼接，重复模式可接受；视差层具有有意设计的深度且无烘焙的碰撞提示。
- **3D（三维模型）**：变换、比例尺、枢轴点、法线、UV 映射、材质、拓扑结构、绑定系统、碰撞代理、LOD 层级和运行时格式均经过检查而非从渲染结果中推断。
- **Rights（版权合规性）**：每份发布的文件均已记录溯源信息和条款，且与项目兼容。

切勿仅凭提示词生成结果就判定资产生产就绪。批准需结合相关技术检查以及引擎内或原生尺度的视觉审查。

## 参考资料

- 关于视觉系统决策和保持一致性，阅读 `references/art-direction.md`。
- 关于精灵图、动画条、瓦片、背景、UI 美术和引擎导入设置，阅读 `references/raster-pipeline.md`。
- 有关从概念模型转换为网格拓扑、纹理映射、glTF/GLB 格式导出、层级细节（LOD）构建、碰撞体检测以及运行时的几何验证，请查阅 `references/three-d-pipeline.md`。
- 关于许可证、生成媒体记录和溯源信息，阅读 `references/provenance.md`。

## 相关技能

- `game-ui-ux`：用于布局设计、导航逻辑、可读性及无障碍交互体验。
- `game-feel`, `shader-programming` 和 `audio-design`：在源美术适配后负责最终呈现效果。
引擎导入与渲染技能，如 `godot-tilemap`（Godot 瓦片地图）、`unity-tilemap-2d`（Unity 二维瓦片地图）、`pixijs-rendering`（Pixi.js 渲染）和 `threejs-gltf-loading`（Three.js glTF 加载）。
