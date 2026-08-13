# 地表无缝贴图

## Production：当前正式资源

### v09 Crisp Cartoon Ground Refinement

目录：[`Production/v09_crisp_cartoon_ground_refinement/`](Production/v09_crisp_cartoon_ground_refinement/)

交互预览：[`preview.html`](Production/v09_crisp_cartoon_ground_refinement/preview.html)

当前共 8 张 2048x2048 无缝 PNG：

| 类型 | 文件 | 用途 |
|---|---|---|
| 草/苔 | [`grass_moss_cushion_crisp.png`](Production/v09_crisp_cartoon_ground_refinement/final/grass_moss_cushion_crisp.png) | 湿润草地、神龛边缘、苔藓区域 |
| 草地 | [`grass_warm_meadow_crisp.png`](Production/v09_crisp_cartoon_ground_refinement/final/grass_warm_meadow_crisp.png) | 默认暖色草地、开阔区域 |
| 湿地草 | [`grass_marsh_teal_crisp.png`](Production/v09_crisp_cartoon_ground_refinement/final/grass_marsh_teal_crisp.png) | 雨林、湿地、冷色区域 |
| 草泥混合 | [`grass_sparse_earth_crisp.png`](Production/v09_crisp_cartoon_ground_refinement/final/grass_sparse_earth_crisp.png) | 草地与泥地的自然过渡 |
| 泥土 | [`dirt_red_clay_crisp.png`](Production/v09_crisp_cartoon_ground_refinement/final/dirt_red_clay_crisp.png) | 暖区、踩踏地、竞技场 |
| 泥土 | [`dirt_dark_humus_crisp.png`](Production/v09_crisp_cartoon_ground_refinement/final/dirt_dark_humus_crisp.png) | 林下、遗迹、深色土壤 |
| 泥土 | [`dirt_sandy_loam_crisp.png`](Production/v09_crisp_cartoon_ground_refinement/final/dirt_sandy_loam_crisp.png) | 河岸、干燥开阔地 |
| 矿土地 | [`dirt_mineral_ochre_crisp.png`](Production/v09_crisp_cartoon_ground_refinement/final/dirt_mineral_ochre_crisp.png) | 矿区、山崖、矿物流域 |

## StyleAnchors：已确认的风格基准

目录：[`StyleAnchors/v07_soft_cartoon_ground_textures/`](StyleAnchors/v07_soft_cartoon_ground_textures/)

交互预览：[`preview.html`](StyleAnchors/v07_soft_cartoon_ground_textures/preview.html)

用户明确认可的三个方向：

- [`flagstone_cartoon_soft.png`](StyleAnchors/v07_soft_cartoon_ground_textures/final/flagstone_cartoon_soft.png)：大块不规则卡通石板。
- [`stone_moss_soft.png`](StyleAnchors/v07_soft_cartoon_ground_textures/final/stone_moss_soft.png)：稀疏扁平石块与苔藓地。
- [`dirt_sparse_pebbles.png`](StyleAnchors/v07_soft_cartoon_ground_textures/final/dirt_sparse_pebbles.png)：低噪点泥地与稀疏圆石。

后续生成新地表时，应继续沿用这些资源的圆润轮廓、低噪点、弱重复和清晰材质识别度。

## Iterations：历史生成迭代

| 版本 | 内容 | 状态 | 预览 |
|---|---|---|---|
| v04 | 第一批基础草地无缝贴图 | 早期基础版本 | `final/` |
| v05 | 青玉草、桃瓣草、雨苔、秋草 | 水墨水粉探索 | [`preview.html`](Iterations/v05_seamless_ground_textures/preview.html) |
| v06 | 草、泥土、碎石、石板高细节版本 | 材质清楚，但 Tile 感和噪点偏重 | [`preview.html`](Iterations/v06_detailed_ground_textures/preview.html) |
| v08 | 基于 v07 扩展的草地与泥地 | v09 的直接前序版本 | [`preview.html`](Iterations/v08_soft_cartoon_ground_expansion/preview.html) |

历史版本用于对比、追溯与二次加工，不建议作为新的默认游戏引用路径。
