# CHANGELOG �?版本历史

> 追加式记录：最新条目在最下方，不回改历史；已失效的表述用新条目更正而不是改写旧条目�?
> 格式：日�?+ 阶段标题 + 关键提交（短 hash�? 说明。逐条细节�?`git log` 为准�?

## 原型期（2026-08-12 ~ 2026-08-13�?

### 2026-08-12 · 核心循环、武器升级与局外商�?
- `d55a9d8` 武器升级系统 Step3 上半�? 把武�?Lv1�? 全落地�?
- `3afe49a` 多类型敌人原型与公共基类；`b815c22` 武器波次 Boss 与调试工具�?
- `a16a3fe` 战斗平衡迭代 + 视频转序列帧工具；`04852ab`、`ab35565` skill 迁移�?AGENTS.md 汉化�?
- `562bdb4` 局外商城一�?Step1 meta 数据层；`76004d0` Boss 撤离抉择与局外商城（商城/仓库/临时背包/存档持久化）�?
- 平衡调参轮：`5e7d633` 玩家反馈调参 �?`018f222`/`9e10849` 玉环重做与披风扩范围 �?`d57dcff` 拔剑斩半�?�?`c68dcfa` 敌人压力曲线 �?`1cab1d9` 拔剑斩命中充�?�?`c51e762` 丹火延长 �?`83a7093` 道剑 Lv6 飞剑质变�?

### 2026-08-13 · 联动、波次、任务与美术探索（原型收尾）
- `f822c3b` comfyui-workflow skill（Krea-2 t2i / MiniMax fl2va）；`2a19735` 角色视频素材；`4402301` Godot 空工程占位�?
- `7a63a70` gpt-image skill 与角色素材；`67860a2`/`1f497a5`/`e2d3443` 风格探索、草甸地图与无缝地贴�?
- `8040088` **武器联动与波次进�?*：原型玩法功能收尾�?
- `5ced693`/`eff2035` Godot 环境沙盒与素材库整理；`cc76ef0` 局内任务规划文档�?
- `19a33fc`/`f7fc83b` 局内随机动态任务与奖励（原型）�?
- `8046e1f`…`7df0ff9` 地面节点式材质多轮迭代（VisualShader 共享材质）�?
- `25deb70` Qwen-Image-Edit pose 工作流并�?comfyui skill�?

## Godot 立项与移植（2026-08-13 ~ 2026-08-14�?

- `378b43f` 立项规划文档（PORT_PLAN / RULES 等），移除旧美术实验场景�?
- `fb8eac9` **M0**：工程脚手架与空�?smoke runner�?
- `ceeb57d`/`f999040` ComfyUI 八方向行走序列帧流水线；`d861387`/`b200f21` 角色与敌人动作素材�?
- `11f17f0` M2/M3 实施计划定稿（`GameProject/PLANS/`）�?
- `00a224a` **M1–M5 单次落库**：核心循环、六武器、敌�?Boss/局流程、联动系统、商�?仓库/任务全部移植完成�?
- `5d9a510`/`596319d` 动画素材整理；项目级 Godot MCP 配置（`.codex/config.toml`）�?

## M6 打磨 · 美术�?UI�?026-08-14 ~ 2026-08-17�?

- `7db4f2a` 可玩美术基线；`1ab6e6b` 占位视觉；`d2b1080` 美术资产台账（ART_ASSET_CONFIG 前身）�?
- `cf491a7` 主题 UI 与调试工具；`e69c48f` 美术 UI 完成与玩家动画恢复�?
- `501f826` 暖纸 UI 打磨；`74cff54` 现代 Q �?UI 重做；`685467c` 地形锐化与图标打磨�?
- `a850e66` UI 字体 Nowar Rounded；`6f83881` Peach Night HUD 重做；`425d98a` 角落岛屿 HUD 布局�?
- `f92c729` 7 �?UI/玩法优化 + Godot MCP 集成；`90fc11c` 第二轮优�?+ 美术审计 + 死资源清理�?
- `5c75d32` 静态资源与草甸地形刷新；`3f0b908` BOM 移除 + 编译修复 + gameplay 调整�?
- `efb78b4` 玩法脚本与选卡 UI 修复；`27bc247` 武器卡概念图补全；`eda8dd1` 进度反馈�?UI 可读性�?

## 美术迭代轮次 4�?�?026-08-17 ~ 2026-08-18�?

- `7a5eaba` 道剑 Lv2 穿透弹道特效贴图（ComfyUI Krea-2 生成）�?
- `0b05978` 补齐�?五轮未落库的美术与玩法缺口�?
- `9515aa0` 记录第八轮候选待办与数值待校准项（OPTIMIZATION_TRACKER）�?
- `76a1451` 弹道与玉环特效精修�?

## 第八�?· 音频框架与数值审计（2026-08-18 ~ 2026-08-19�?

- `4cf0420` **feat(audio)**：AudioManager autoload + 披风/玉环 SFX（视频生成音轨提取）；账�?SFX 2/22、BGM 0/6�?
- `250a430` **feat(balance)**：稀有掉落来源收敛、稀有加成封顶、雷�?玉环再平衡�?
- `a86c917` chore(repo)：仓库卫生规则（.gitattributes/.gitignore�? 音频生成工作�?skill�?
- `0e89026` fix(weapons)：js 侧雷�?thunderAoE 半径对齐 RULES 真值（95�?0）�?
- `671cea9` feat(vfx)：披�?丹炉序列�?sprite-sheet 图集入库（运行时集成待做）�?
- `98248dc` docs(godot)：六�?GameProject 文档同步（BALANCE/PROGRESS/OPTIMIZATION_TRACKER/ART_ASSET_CONFIG/AGENTS/PORT_PLAN）�?
- `ab77e16` feat(audio)：新增开炉音�?sfx_furnace_open（监听丹火炉累计开炉数触发，高频节�?0.12s）；SFX 账面 2/22�?/23，s22 冒烟扩展�?15�?19 项）�?

## 2026-08-19 · 文档体系重整

- 删除过时文档：根 `DESIGN.md`、`Docs/wave-difficulty-table.md`、`Docs/project-status-summary.md`、`Docs/art-resource-refresh-2026-08-16.md`（信息已�?`GameProject/RULES.md`、`BALANCE.md`、`PROGRESS.md`、`ART_ASSET_CONFIG.md` 承接）�?
- 重写�?`README.md`；新建本文件（`CHANGELOG.md`）与 `Docs/README.md`（文档地�?+ 更新纪律）�?
- Docs 5 个保留文件加状态头/复核注记；`AGENTS.md` 增补文档纪律�?Godot 命令；修�?RULES.md / PLANS 中的 DESIGN.md 引用�?
- 更正：Godot smoke 检查数 415�?19 �?`ab77e16` 新增 s22 检查所致（此前误归因，历史行不回改）；已更�?README �?ART_ASSET_CONFIG 现状行�?
- 补同�?`ab77e16`（开�?SFX）的文档缺口：SFX 账面 2/22�?/23 同步�?PROGRESS / OPTIMIZATION_TRACKER / ART_ASSET_CONFIG / README（该提交当时未带文档，违反同提交纪律，此处补录）�?

## 2026-08-19 · 第八轮收尾（补录�?

- `cbab517` **feat(vfx)**：序列帧运行时接入——新�?`logic/systems/flipbook.gd` 纯函数裁帧；`art_catalog.gd` �?`cloakFireBurstAnim` / `furnaceFlameAnim`（`VFX_TEXTURES` 22�?4）；`world_art_view.gd` 披风 Lv6 爆发一次性播�?+ 丹炉/余烬/丹火循环火焰（世界坐标位置相位）；另补齐 **4 类敌人预�?*：bomber 自爆蓄力（加速闪�?收缩环）、enhanced_chaser 狂暴前（脉动光环+旋转断口）、Boss 弹幕蓄力（扩张环+倒计时弧）、ranged 枪口蓄力点；新增 s24_flipbook 冒烟章节�?19�?36 �?/ 24�?5 场景）。该提交未带文档，违反同提交纪律，此处补录�?
- `ff44fac` **feat(audio)**�?1 �?SFX + 3 �?BGM（battle/boss/menu）入库；磁盘 SFX �?24 条，覆盖 `SFX_PATHS` 全部 23 键（部分键共用文件），BGM 3/6（rest/extraction/summary 缺，gameplay 实际文件�?battle）；s22 仅抽查首�?3 �?SFX + bus layout，无回归。该提交未带文档，违反同提交纪律，此处补录�?
- `12b1180` **fix(vfx)**：披风火焰爆燃序列帧重抠像——BiRefNet 显著性抠像侵蚀弥散火焰（关键帧覆盖�?82%�?9.8%），改用亮度阿尔法重键（remat_luma.py：黑点提�?/ 0.02 噪底 / gamma 0.8 光晕 / 反预�?+ 0.10 clamp / bleed 24），图集原位重建，硬规格�?000×2000 RGBA8�?×5、cell 400、fps 4.83871）不变；覆盖率弧线恢复为蓄力 53�?2% �?爆发 82�?8% �?单调消散；生产归�?`ArtAsset/Image/VFX/gen_20260819_anim/`�?
- 现状同步：Godot smoke 436 �?/ 25 场景；序列帧运行时集成完成；音频 SFX 24/23 键、BGM 3/6；敌人预警已�?4 类（shield phase 仍缺）。SFX 键位重映射、BGM 音量/交叉淡化（audio_manager WIP）与 fireBallAnim（并行会�?WIP）未落库�?

## 进行�?/ 已知缺口

- 对象�?+ 180 敌人压测（`GameProject/OPTIMIZATION_TRACKER.md` 候选）�?
- 音频收尾：BGM �?3 条（rest/extraction/summary）；SFX 24 条已覆盖 23 键，键位重映射与 BGM 音量/交叉淡化参数在工作区 WIP 待落库�?
- 盾兵攻防相位表现（其�?4 类敌人预警已�?`cbab517` 补齐：bomber/enhanced_chaser/Boss/ranged）�?
- Windows 导出流程�?

## 2026-08-19 �� ��Ƶ��β + Lv6 �ʱ����

- 0bc9de9 feat(av)����Ƶ�¼�ӳ����⡪��audio_manager.gd SFX ��λ��ӳ�� + BGM ����/���浭��������ʽ����fire_ball_anim.png flipbook ͼ����⣨2.9MB����game_overlay/game_view/world_art_view ��Ƶ����ͬ�����¡�
- 17720a5 chore(perf)��ȷ���Կռ������׼����tools/perf_grid_benchmark.gd + _impl.gd��SEED=20260819��60/120/180/240 ���˹�ģ�������ѯ���ٱ� ��4.5~��7.2��
- 4d6b7c9 chore(av)��������汬������֡���Ȱ������ؿ��񣨸����ʻ��߻ָ���+ ���� 3 ��ȱʧ .uid �ļ���
- �ĵ���OPTIMIZATION_TRACKER.md ���������֡�6 ���� Lv6 �ʱ��Ӿ����컯����Ʒ������׷�������/���Ȱٹ�ҹ��/��伫��/��¯��ת��������״���������ȼ�����
- .gitignore ���� ArtAsset/Flipbook/��88MB ����Դ֡������汾�⣩��
- ȫ�� git proxy �Ƴ�����ǰ���´��ļ� push RPC ��ʱ����
