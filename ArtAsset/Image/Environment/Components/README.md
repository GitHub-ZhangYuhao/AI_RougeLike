# 场景组件

## BlackKey

目录：[`BlackKey/`](BlackKey/)

这组组件从“开放草甸”地图概念中拆分，所有图片使用纯黑背景，便于运行时通过色键或亮度键提取。

- [`01_trees/`](BlackKey/01_trees/)：桃树大、中、幼苗。
- [`02_rocks/`](BlackKey/02_rocks/)：苔石单体与组合。
- [`03_plants/`](BlackKey/03_plants/)：花丛与草簇。
- [`04_ground_patches/`](BlackKey/04_ground_patches/)：草甸色块和弯曲风草带。
- [`COMPONENTS.md`](BlackKey/COMPONENTS.md)：组件清单、参考地图和推荐图层顺序。

碰撞体与绘制轮廓应在引擎内独立配置，不要直接根据黑底图片边缘生成复杂碰撞。
