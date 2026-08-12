# 实现方案：Boss 撤离 + 局外商城（一期完整闭环）

> 状态：设计已拍板，待实现
> 日期：2026-08-12
> 关联文档：Notion《AI Rogue Like Design》→「Boss 撤离与局外商城系统（已拍板 · 一期）」；`Docs/boss-extraction-shop-dynamic-tasks.md`（原始设计稿）

## 一、已确认设计决策

| # | 决策点 | 结论 |
|---|--------|------|
| 1 | 撤离节奏 | 每个 Boss 击败后出现「撤离 / 继续深入」抉择；选择继续后，下一个 Boss 仍可再次抉择 |
| 2 | 物品体系 | 全新局外物品体系：暗晶（货币）+ 三阶材料（碎片 / 辉光精华 / 灵魂结晶），卖出价 5 / 20 / 80 暗晶 |
| 3 | 掉落规则 | 概率 = min(8% + 3% × (Boss 阶位 − 1), 20%)；阶位影响高档材料权重；高阶 Boss 有保底品阶 |
| 4 | 撤离收益 | 临时背包物品入仓库 + 「当前波数 × 2」暗晶结算奖励 |
| 5 | 死亡惩罚 | 临时背包全损（已入库物品不受影响） |
| 6 | 商城 | 首版只卖 6 种永久属性（复用局内属性池），每项最高 Lv10，价格递增 |
| 7 | 仓库 | 纯存放 + 卖出（单卖 / 全卖）；备战功能留待二期 |
| 8 | 持久化 | localStorage（headless 环境内存兜底） |
| 9 | 范围 | 撤离 + 商城一次交付完整闭环；随机动态任务暂缓、后续单独立项 |

## 二、核心数值表

### Boss 掉落表

Boss 阶位 = 本局第几个被击杀的 Boss。

| Boss 阶位 | 掉落概率 | 材料权重 T1/T2/T3 | 保底品阶 | 掉落数量 |
|-----------|---------|-------------------|----------|----------|
| 1 | 8% | 100 / 0 / 0 | — | 1 |
| 2 | 11% | 70 / 30 / 0 | — | 1 |
| 3 | 14% | 45 / 45 / 10 | ≥ 辉光精华 | 1~2 |
| 4 | 17% | 25 / 45 / 30 | ≥ 辉光精华 | 1~2 |
| 5+ | 20%（上限） | 10 / 40 / 50 | ≥ 灵魂结晶 | 2 |

### 材料表

| 物品 | 阶级 | 卖出价（暗晶） |
|------|------|----------------|
| 碎片 | T1 | 5 |
| 辉光精华 | T2 | 20 |
| 灵魂结晶 | T3 | 80 |

### 商城属性表

- 6 种属性复用局内属性卡（`ATTR_CARDS`）效果，每级效果 = 1 层属性卡：
  - 伤害 +15%、护甲 +15、拾取范围 +50px、经验倍率 +15%、最大生命 +20、移速 +6%
- 每项属性最高 Lv10
- 价格曲线：Lv k = round(20 × 1.6^(k−1)) → 20 / 32 / 51 / 82 / 131 / 210 / 336 / 537 / 859 / 1374（满级单项合计约 3632 暗晶）
- 属性开局即生效，与局内属性卡加法叠加，不占用卡牌叠加上限（`attrMaxStack`）

### 撤离结算

- 暗晶奖励 = 撤离时波数 × 2
- 临时背包全部材料转入局外仓库

## 三、状态机改动

```text
[新增] menu ──开始──▶ opening ──▶ playing ──▶ (Boss波清空) extraction
        ▲                                        │撤离            │继续
        │                                        ▼                ▼
        └──────── summary ◀────────── (波数×2暗晶+背包入库)      playing(休整→下一波)
        ▲
        └── dead (显示临时背包损失) ◀── playing
menu 可进入：shop（购买属性） / storage（卖出物品）
```

状态说明：

| 状态 | 说明 |
|------|------|
| `menu` | 主菜单（新增）：开始游戏 / 商城 / 仓库；游戏启动初始状态由 `opening` 改为 `menu` |
| `extraction` | 撤离抉择（新增）：展示本次战利品清单、波数×2 奖励预览、「撤离 / 继续深入」按钮；战斗暂停 |
| `summary` | 撤离结算（新增）：展示本局统计与入库收益，确认后回主菜单 |
| `shop` | 商城（新增）：属性列表 + 等级 + 价格 + 购买；显示暗晶余额 |
| `storage` | 仓库（新增）：材料数量、单卖 / 全卖；显示暗晶余额 |
| `dead` | 死亡界面增加临时背包损失信息，返回主菜单 |

## 四、文件改动清单

### 新增（5 个文件）

| 文件 | 职责 |
|------|------|
| `js/meta/items.js` | 材料定义（id / 名称 / 图标 / 阶级 / 卖出价） |
| `js/meta/drops.js` | Boss 掉落掷骰：概率、权重、保底、数量（读 CONFIG.meta） |
| `js/meta/shop.js` | 6 属性定义、价格曲线 `priceForLevel(k)`、购买校验与扣款 |
| `js/meta/save.js` | 存档读写：localStorage + headless 内存兜底、版本号、损坏重置 |
| `js/ui/meta-screens.js` | 主菜单 / 商城 / 仓库 / 撤离 / 结算 5 个界面的绘制与点击命中 |

### 修改（7 个文件）

| 文件 | 改动 |
|------|------|
| `js/config.js` | 新增 `CONFIG.meta`：掉落表、材料卖价、属性价格曲线、波次奖励系数（×2） |
| `js/game.js` | 新状态机分支；`tempBackpack`；`onBossWaveCleared()` 挂载点；开局注入 `metaStacks`；死亡损失处理；新状态的输入路由 |
| `js/cards.js` | `computeMods(attrStacks, metaStacks)` 支持双来源叠加；卡池判定仍只看局内 `attrStacks` |
| `js/systems/waves.js` | Boss 波清空时改调 `game.onBossWaveCleared(this)` 而非直接 `_beginRest()`；继续深入后由 game 调用继续休整 |
| `js/hud.js` | 战斗 HUD 显示临时背包数量；死亡界面加损失信息 |
| `tools/headless-smoke.mjs` | 新增 6 项检查（见测试计划） |
| `Docs/boss-extraction-shop-dynamic-tasks.md` | 回填全部已确认参数；修正「避免数值成长」表述为「首版以属性成长为主，内容解锁留待后续」 |

## 五、存档结构（localStorage）

```js
{
  version: 1,
  darkCrystals: 0,                                    // 暗晶
  storage: { shard: 0, essence: 0, soulCrystal: 0 },  // 仓库材料
  metaLevels: {                                       // 商城属性等级
    damage: 0, armor: 0, magnet: 0, xp: 0, maxHp: 0, moveSpeed: 0,
  },
  stats: { runs: 0, extractions: 0, bestWave: 0, totalBossKills: 0 },
}
```

## 六、测试计划（headless-smoke 新增 6 项）

1. Boss 掉落概率边界：阶位 1 = 8%，阶位 5+ = 20% 上限；保底品阶生效（阶 3+ ≥ T2，阶 5+ = T3）
2. 撤离流程：Boss 波清空 → `extraction` 状态；选撤离 → 背包入仓库 + 暗晶 = 波数×2 → `summary` → 存档已写入
3. 继续深入：选继续 → 回战斗，临时背包保留；下一个 Boss 波再次出现抉择
4. 死亡损失：带背包死亡 → 背包清空、仓库存量不变
5. 商城：购买扣款与升级正确；余额不足拒绝；满级拒绝；价格曲线 = round(20×1.6^(k−1))
6. 仓库：单卖 / 全卖正确加暗晶；开局属性生效（metaLevels 注入后 mods 数值正确）

## 七、实现顺序

1. **meta 数据层**：`items.js` / `drops.js` / `shop.js` / `save.js` + `CONFIG.meta`
2. **状态机**：waves.js 挂载点 + game.js 新状态与临时背包 + computeMods 双来源
3. **UI**：meta-screens.js 五个界面 + hud.js 背包显示 + 输入路由
4. **测试**：扩展 headless-smoke，`npm run smoke` 全绿
5. **文档**：回填 `Docs/boss-extraction-shop-dynamic-tasks.md`

## 八、验收标准

- `npm run smoke` 全绿（原 11 项 + 新增 6 项）
- 浏览器手测闭环：主菜单 → 开局 → 第 5 波 Boss → 撤离抉择（两个分支都走通）→ 商城购买属性 → 仓库卖出 → 第二局开局属性生效
- 刷新页面后存档保留（货币 / 仓库 / 属性等级）

## 九、风险与注意

- `computeMods` 签名变更需同步所有调用点（game.js 的 `recomputeMods`、debug 工具）
- headless 环境无 localStorage，`save.js` 必须内存兜底，否则冒烟测试崩溃
- Boss 波结束钩子改动要保留「Boss + 全部援军阵亡才算清场」的既有语义（wave ≥15 有援军）
- 死亡重开现有流程需改道为回主菜单，避免跳过新 UI
