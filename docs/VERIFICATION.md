# 治理原型验收记录

日期模拟：`..\GodotPortable_4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://tools/test_simulation.gd` 输出 `simulation-tests: PASS`。覆盖 1965-01-01 加 31 天、闰年 1964-02-28/29、普通年 1965-12-31 跨年。

运行检查：`..\GodotPortable_4.7.2\Godot_v4.7.2-stable_win64_console.exe --headless --path . --quit-after 2` 完成且无 `ERROR` 或 `SCRIPT ERROR`。治理测试：`--headless --path . --script res://tools/test_governance.gd` 输出 `governance-tests: PASS`；覆盖710地区、17°N分类、统一行动成本、快捷键与按钮、谈判冷却、三类事件双分支、资源不足保留待决、28天自动事件、跨周推进、军方底线倒台、20周成功、结束锁定和重新开始、选区 UI 更新。日期测试：`--headless --path . --script res://tools/test_simulation.gd` 输出 `simulation-tests: PASS`。

治理迭代：完整加载 710 个地区；右侧 Control 面板显式显示预算、政治资本、三派支持、稳定度、选区详情、行动成本、反馈和事件选项。地图使用实际 `Control.clip_contents` 裁剪视口，填色模式由阵营、民心、叛乱驱动，源环采用安全的渲染填充路径避免三角化错误。稳定度由三派支持与南方地区民心/治安/叛乱指标共同计算。

交互实现：左键仅在 `MAP_RECT` 内处理，并使用 `Geometry2D.is_point_in_polygon` 命中实际轮廓环；地图外/侧栏不会改变选择。滚轮缩放和中键拖动共享同一坐标变换，因此命中逻辑随缩放拖动保持一致。暂停或事件待决时 `_process` 不推进；运行时按天循环，严格在第7天周结算和第28天触发事件，结束后快捷键与按钮保持无效并提供重新开始。

交互集成：`..\GodotPortable_4.7.2\Godot_v4.7.2-stable_win64_console.exe --path . --script res://tools/test_interaction.gd` 使用真实场景与 `_unhandled_input` 事件路径运行，输出 `interaction-tests: PASS`，退出码 0。覆盖区域内点击、海上空白点击、侧栏点击、空格暂停/继续、1/2/4 速度、累计余数、缩放与拖动后再次命中。

视觉证据：同一集成脚本使用非 headless Godot 的 OpenGL Compatibility 渲染，在 `RenderingServer.frame_post_draw` 后保存 [stage1-preview.png](stage1-preview.png)；截图展示了选中的南方地区、显式治理面板和真实的“军方要求增加预算”待决事件，两种方案的成本均可见。`test_coup_interaction.gd` 另保存 [coup-preview.png](coup-preview.png)，显示政变暂停状态、单位标记、双方进度和首都/电台/军营的实际地区名。

来源与许可限制：`vietnam-provinces-game.json` 是工作区既有文件，本阶段仅追溯到本地文件，未能从文件元数据确认其上游来源或许可证。因此项目不宣称这些轮廓可独立再分发；只把它们作为本地原型输入，并保留来源不确定性。

导出：`powershell -ExecutionPolicy Bypass -File tools\build_windows.ps1` 生成 `builds\VietnamWar1965-governance.exe`；原有 `builds\VietnamWar1965-stage1.exe` 保留。

性能验证：`--headless --path . --script res://tools/test_performance.gd` 在完整 710 地区上实测 `geometry_rebuild_ms=278.72`（主动重建成本）、缓存绘制命令 CPU 计时 P95 `28.00ms`，变换场景 CPU 计时 P95 `28.83ms`；这两个值不是旧版 FPS 对比。非 headless OpenGL Compatibility（NVIDIA GeForce RTX 3060 Laptop GPU）用 `tools/test_frame_performance.gd` 实测60个空闲帧 P50/P95 `16.67/17.53ms`，实际滚轮缩放与拖动路径60帧 P50/P95 `16.61/17.36ms`。地图现在只在加载、选择/行动或模式切换时更新 SubViewport 纹理，镜头变换只缩放/平移纹理；710 地区数据本身没有删减或降采样。

上手与政变：右侧面板默认选中南方地区，分为“治理/政变”两页签；治理页提供三步引导、下一步建议、行动成本/效果和禁用原因，政变页提供10支部队选择器、首都/电台/军营三个目的地按钮、移动提示和页内反馈。新增10支全国部队（政府5、政变3、中立2）。政变测试覆盖全国冻结、反政变方权限、政变方玩家越权拒绝、中立禁止、AI调集、三处控制点不同结果、反政变胜利解锁和政变方胜利失败。

公开仓库：远端为 `git@github.com:myfines/fluffy-waddle.git`，当前 `master` 已推送到 commit `287c958`。由于本机 SSH 公钥认证失败，本次使用同一 GitHub 地址的一次性 HTTPS push 完成上传，origin 配置仍保持用户提供的 SSH 地址。仓库不包含未知许可的710轮廓、派生轮廓、exe、release 或 Godot缓存；干净 clone 使用许可明确的 `data/demo_regions.json` 启动，且干净 clone 治理测试通过。

清理记录：本轮只移除了可明确归因于本轮截图生成的未跟踪 `docs/coup-preview.png.import`（945 bytes）；用户原有构建和 stage1 版本均保留。清理后工作区（含本地数据/构建）约 717,854,343 bytes，`builds` 目录约 563,819,736 bytes，最新版治理 exe 为 114,935,352 bytes。
