# 场景美术资源目录

本目录按**资源用途**整理，不再按生成批次全部平铺。所有历史生成结果均保留，没有删除原图或旧版本。

## 当前推荐

- **正式地表材质**：[`GroundTextures/Production/v09_crisp_cartoon_ground_refinement/`](GroundTextures/Production/v09_crisp_cartoon_ground_refinement/)
- **正式地表预览**：[`preview.html`](GroundTextures/Production/v09_crisp_cartoon_ground_refinement/preview.html)
- **风格基准**：[`GroundTextures/StyleAnchors/v07_soft_cartoon_ground_textures/`](GroundTextures/StyleAnchors/v07_soft_cartoon_ground_textures/)
- **场景组件**：[`Components/BlackKey/`](Components/BlackKey/)

## 目录结构

```text
Environment/
├─ README.md
├─ StyleExploration/       # 场景氛围与整体风格探索
├─ MapConcepts/            # 完整地图构图方案
├─ Components/             # 树木、岩石、植物、地表贴花等组件
└─ GroundTextures/
   ├─ Production/          # 当前建议在游戏中使用的正式材质
   ├─ StyleAnchors/        # 已确认的美术方向基准
   └─ Iterations/          # 生成过程与旧版材质，保留用于追溯
```

## 分类说明

### 地表材质

详见 [`GroundTextures/README.md`](GroundTextures/README.md)。当前正式版本是 v09：更清晰、具象、卡通，减少了水彩噪点和明显的 Tile 重复感。

### 场景组件

详见 [`Components/README.md`](Components/README.md)。目前组件采用纯黑背景，运行时通过色键/亮度键提取。

### 地图概念

详见 [`MapConcepts/README.md`](MapConcepts/README.md)。这里保存完整地图构图，不作为直接铺设的无缝地表。

### 风格探索

详见 [`StyleExploration/README.md`](StyleExploration/README.md)。这里保存早期场景气氛与色彩方向。

## 地表版本规则

每个完整材质批次通常包含：

- `raw/`：GPT Image 原始生成图。
- `final/`：经过无缝处理、清理和放大的游戏用候选图。
- `previews/`：2x2 或 3x3 重复检查图与总览图。
- `preview.html`：浏览器交互预览，可检查铺设尺度与重复感。
- `README.md`：该批次的目标、处理方式和资源说明。

正式使用时优先引用 `Production/*/final/`，不要直接依赖 `Iterations/` 中的实验资源。
