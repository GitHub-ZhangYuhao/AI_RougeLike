# 微信小游戏打包发布 Skill

微信小游戏打包发布自动化流程，专门用于 Godot 4.5.1 + godothub godot-minigame 插件的导出链路。

## 触发方式
- `/wechat-minigame-publish`
- `/微信小游戏发布`
- `/小游戏打包`
- `/发布小游戏`

## 前置条件
1. **Godot 4.5.1 引擎**：必须使用 Godot 4.5.1（位于 `GameEngine/4.5/Godot.exe`），小游戏插件只认 4.5 版本
2. **微信开发者工具**：已安装并开启服务端口（设置 → 安全设置 → 开启服务端口）
3. **AppID**：已注册微信小游戏 AppID
4. **项目状态**：Godot 项目已通过冒烟测试

## 核心流程

### 1. AppID 配置
- 替换 `GameProject/export_presets.cfg` 中的 AppID
- preset.2（微信全量档）和 preset.3（抖音 slim 档）两处都需要替换
- 当前配置文件路径：`C:\WorkSpace\AIGame\GameProject\export_presets.cfg`

### 2. 导出执行
使用专用导出脚本：`GameProject/tools/minigame_export.ps1`

```powershell
# 导出微信全量档（preset.2）
cd GameProject; powershell -ExecutionPolicy Bypass -File tools\minigame_export.ps1 -Presets 2

# 导出抖音 slim 档（preset.3）
cd GameProject; powershell -ExecutionPolicy Bypass -File tools\minigame_export.ps1 -Presets 3

# 同时导出两档
cd GameProject; powershell -ExecutionPolicy Bypass -File tools\minigame_export.ps1
```

### 3. 导出脚本功能
- **MCPRuntime 清理**：自动移除开发用的 MCPRuntime autoload
- **Slim 档处理**：preset.3 会自动应用严格的尺寸限制（sprites/vfx 长边 256、terrain/ui 长边 512）
- **.import 管理**：自动快照和恢复 .import 文件，保持仓库状态一致
- **包体验证**：自动检查包体大小和 MCPRuntime 引用

### 4. 包体大小限制
- **微信全量档**：总包 ≤ 30MB
- **抖音 slim 档**：总包 ≤ 20MB
- **当前状态**：
  - 微信全量档：29.05 MB（余量 0.95 MB）
  - 抖音 slim 档：19.37 MB（余量 0.63 MB）

### 5. 微信开发者工具验证
使用 CLI 进行自动化预览：

```powershell
# 预览微信全量档
cd "C:\Program Files (x86)\Tencent\微信web开发者工具"
.\cli.bat --port 23720 preview --project "C:\WorkSpace\AIGame\GameProject\build\minigame\wx"

# 预览抖音 slim 档
.\cli.bat --port 23720 preview --project "C:\WorkSpace\AIGame\GameProject\build\minigame\wx-slim"
```

### 6. Brotli 压缩处理
- **现状**：Godot 导出的 WASM 文件使用 Brotli 压缩（.br 扩展名）
- **兼容性**：微信开发者工具原生支持 .br 文件，无需解压
- **注意**：解压后文件会从 6MB 增长到 58MB，超过微信 4MB 主包限制
- **处理**：保持 .br 压缩格式，不进行解压

## 关键配置

### export_presets.cfg 关键设置
```ini
[preset.2.options]
"微信小游戏/游戏_AppID"="wxe982a8234ada9560"
"微信小游戏/小游戏项目名"="AIGame"
"微信小游戏/游戏方向"="landscape"
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=true
```

### project.godot 关键设置
```ini
rendering/textures/vram_compression/import_etc2_astc=true
rendering/textures/vram_compression/import_s3tc_bptc=false
```

## 产物位置
- **微信全量档**：`GameProject/build/minigame/wx/`
- **抖音 slim 档**：`GameProject/build/minigame/wx-slim/`

## 验证清单
1. ✅ AppID 已替换为真实值
2. ✅ 包体大小符合平台限制
3. ✅ 微信开发者工具预览成功
4. ✅ 横屏显示正常
5. ✅ 基本游戏功能正常
6. ✅ 性能表现可接受
7. ⏳ 真机测试通过

## 常见问题

### Brotli 压缩问题
- **问题**：WASM 文件使用 .br 压缩，担心兼容性
- **解决**：微信开发者工具原生支持，无需处理

### 包体超限
- **问题**：包体超过平台限制
- **解决**：使用 slim 档（preset.3）或进一步优化资源

### 导出失败
- **问题**：导出过程中出现错误
- **解决**：检查 Godot 4.5.1 是否正确安装，插件是否配置正确

## 后续步骤
1. 真机测试验证
2. 抖音开发者工具验证
3. 横屏真机验证（抖音最大风险）
4. 账号/合规配置（用户自行处理）