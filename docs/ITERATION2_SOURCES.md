# 第二阶段来源与取舍

- [OpenGS C#](https://github.com/JDSweet/opengs-csharp)：MIT。参考可选择区域与地图模式；未复制代码或素材。
- [Grand Strategy Game](https://github.com/SamTheBlow/grand-strategy-game)：MIT。参考数据驱动和规则可调思路；未复制代码或素材。
- [Conquest](https://github.com/argosopentech/Conquest)：MIT 或 CC0。参考策略地图交互；未复制代码或素材。
- [Godot](https://github.com/godotengine/godot)：MIT。使用自带 Control/2D 绘制 API。
- [OpenStreetMap Racer](https://github.com/egore/openstreetmap-racer)：MIT。参考地图数据的加载期缓存/分块思路；本项目没有复制其代码、数据或素材。
- [Fantasy Map Sandbox](https://github.com/AlfredHus/Fantasy_Map_Sandbox)：以 Godot 地区节点和地图模式做实验。仅参考其地区选择组织方式；本项目没有复制代码、数据或素材。

性能取舍：本项目仍保留本地 710 个细地区数据；加载时清理环线、投影并计算安全填充扫描段，运行时只绘制缓存段，通过 Node2D transform 实现缩放/平移。这样避免每次输入和每天推进重复投影、清理和三角化。Godot 自带 Polygon2D 文档说明其会对多边形做内部填充处理；本项目对不规则源环使用预检与扫描段，避免渲染器错误。

`vietnam_districts.json` 与 `vietnam_polygons.json` 是工作区既有文件，本迭代完整采用 710 个细分地区以避免抽样孔洞。本迭代只确认其为本地输入，未确认上游版权或许可证，因此不宣称轮廓数据可独立分发；区域明确标为游戏设计抽象。`F:\somegames\反叛公司` 仅查看目录与文件清单，未运行、逆向或提取商业素材；其界面只作为交互灵感。
