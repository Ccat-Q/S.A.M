# 视觉与交互规范

## 已核实的参考

- [Observation 官方介绍和截图](https://store.steampowered.com/app/906100/Observation/)：玩家作为 S.A.M. 操作摄像头和控制系统。HUD 含位置、视角、准星及缩放刻度。
- [Jon McKellan 访谈，2019-05-22](https://www.gamedeveloper.com/design/making-the-player-the-ai-in-outer-space-thriller-i-observation-i-)：先配对后交互；统一字体但允许设备界面差异；模拟视频质感。
- [开发者 IGF 访谈](https://www.gamedeveloper.com/business/road-to-the-igf-no-code-s-i-observation-i-)：摄像头切换、设备工具和 Response Mode。不能把 Response Mode 描述成通用大模型命令终端。
- [地图与 Memory Core 流程](https://gamefaqs.gamespot.com/xboxone/293943-observation/faqs/80526/prologue)：空间舱段导航、径向数据浏览与组合。知识图谱是本项目未来扩展。

资料仅作为设计依据，不打包游戏截图、字体、Logo、舱段布局或谜题资产。摄像头场景由代码原创绘制。

## 原创视觉系统

背景 #050708 / #0B0E0F，文字 #D8E2DF，主色 #8FC9BC；琥珀 WARNING、低饱和红 CRITICAL、灰 OFFLINE、蓝灰通信线路。供电线路用琥珀区分。主色是项目品牌选择，不是原作取色结果。

1px 边框、方形模块、技术标签、等宽读数、细刻度、小型状态灯。使用系统字体及中文 fallback，不复用原作字体。不采用 SaaS 卡片、霓虹大渐变、Emoji 或巨型控制按钮。

字体/状态/反馈统一；设备控制面板按能力变化：电源采用隔离/恢复、门禁开闭、灯光刻度、云台轴值、传感器诊断。可见按钮必须反映权限和连接状态。

## 信息组织

iPhone：顶部状态 + 主视图 + 概览/地图/摄像头/告警/更多底部导航；地图和摄像头可全屏，Inspector 使用可滚动面板。
iPad 大屏：导航 + 主显示 + Inspector + 底部事件流。Overview 以设施缩略图和故障入口为中心。

FACILITY 与 NETWORK 使用同一活动节点，切换保留上下文。空间关系与依赖不能在同一视图中混作一种线路。摄像头目标点击打开同一节点 Inspector；告警到地图/摄像头/设备/日志保持 Node ID。

## 视觉效果与可用性

模拟画面明确标注 SIMULATION。摄像头 pan/tilt/zoom 同时变换场景和目标命中区域。未收到信号时显示 NO SIGNAL，不展示正常场景。CRT 默认轻度，噪声、色差、扰动默认关闭，均可关闭。减少动态效果设置停止装饰运动。

实际请求驱动 SCANNING/AUTHENTICATING/ESTABLISHED，不人为插入等待。标识可细小，交互区域仍至少 44 逻辑像素。效果不覆盖控制文字。错误必须提供可读解释并保留可追溯错误码。
