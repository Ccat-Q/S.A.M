# 视觉与交互规范 / SAM.OS 第二轮

## 参考与原创边界

- [Observation 官方介绍和截图](https://store.steampowered.com/app/906100/Observation/)：AI 通过摄像头、设备和系统界面感知并行动。
- [Jon McKellan 访谈](https://www.gamedeveloper.com/design/making-the-player-the-ai-in-outer-space-thriller-i-observation-i-)：先配对后交互；设备界面允许差异；模拟视频显示质感。
- [开发者 IGF 访谈](https://www.gamedeveloper.com/business/road-to-the-igf-no-code-s-i-observation-i-)：摄像头切换、设备工具与 Response Mode。后者不等于通用大模型终端。
- [地图和 Memory Core 流程参考](https://gamefaqs.gamespot.com/xboxone/293943-observation/faqs/80526/prologue)：空间舱段导航、径向数据浏览和组合。

不打包、描摹游戏截图、Logo、字体、地图布局或谜题。站体、设备电路、光学场景均为原创。本轮按用户明确要求替换第一版 Dashboard 式布局；业务服务、Node 身份与安全协议保持不变。

## 六个视觉世界

1. **SAM.OS**：开放黑场、细小英文代码、局部短线、非对称读数；降低品牌标识。没有统一矩形 Card。
2. **RELOCATION**：连续的原创线框站体、压力舱、连接走廊、散热翼和摄像机位置。第一层只显示 MODULE / CAMERA LOCATION / ALERT；进入 Module 后显示内部设备位置。
3. **NETWORK**：独立数字依赖视图。通信采用蓝青色，供电采用琥珀色，故障采用低饱和红；保留缩放、过滤、搜索、线路高亮与节点检查。
4. **CAMERA**：原创预渲染工业舱段、真实材料与灯光；白色克制 HUD 贴边。场景不是绿色线框，也不是实时视频；明确标记 MOCK FEED / PRE-RENDERED。
5. **SYSTEM LINK**：直角系统覆盖层，仅少量公共字段。扫描识别后可配对；连接后进入机器自己的工程界面。
6. **MEMORY CORE**：中心留空的径向关系场。外围显示现有事件、节点状态引用和场景媒体引用；选中节点放大并显示有真实数据依据的彩色关系。

## Tokens / 字体 / 导航

`client/lib/ui/theme.dart` 的 `SamTokens` 管理背景、面板底色、磷光、文字、暗色、细线、琥珀、蓝色、告警、线宽和效果强度。设备通过局部 accent 覆盖颜色：POWER 琥珀，ENVIRONMENT 淡绿，SERVER / NETWORK 蓝色，CAMERA 白色。

背景 #050708 / #0B0E0F，文字 #D8E2DF，淡青主色。主色是项目选择，不声称来自原作取色。读数 Roboto Mono，系统标题 Roboto Condensed，保留系统中文 fallback；使用 [Google Fonts 官方仓库](https://github.com/google/fonts) 的 SIL OFL 字体，许可证打包进应用。

系统代码为英文，中文辅助解释；状态保留 ONLINE / OFFLINE / ESTABLISHED / NOMINAL / FAULT。标题通常 13–18 逻辑像素，辅助读数 8–12；细小视觉不缩小触控命中区域，交互至少 44 逻辑像素。

顶栏为小型 `SAM.OS / REV`、系统时码、状态与文字 Tab；底部统一为 `01 SYS / 02 RELOC / 03 CAM / 04 ALERT / 05 CORE` Soft Key Strip。没有大图标、胶囊高亮、Material Navigation 或圆角 Bottom Sheet。CORE 索引提供设备、Network、Memory、日志、设置入口。平板沿用终端语言，控制覆盖层靠右；手机控制覆盖层靠下，可滚动。

## 感知与连接链

RELOCATION → MODULE SELECT → CAMERA → TARGET → SCAN → IDENTIFY → PAIR → LINK → DEVICE INTERFACE。

Module Select 显示模块名称、状态、相机缩略图、可用视角以及 RELOCATE。点击站体不会直接弹出设备资产表。内部设备层与独立 Network 仍提供已知节点检查，保证既有设备管理能力可达。

摄像头目标默认只显示微小点；瞄准后出现准星和 TARGET FOUND，扫描后才展示身份与轻角标。场景与命中区域使用同一 pan / tilt / zoom 变换，切换相机使用短扫描重绘。离线显示 NO SIGNAL；不能假装有视觉。告警已知的上游故障设备允许从此上下文进入总线 System Link，以恢复供电；仍须服务端 SCAN 和 Link 校验。

Pair 首次显示三个随机符号，按提示触摸完成，正常约 2–3 秒；错误只重置输入，不发送 Link 请求。已完成的界面可 Quick Pair。它是客户端接入表现，不是认证因子，不替代扫描凭据、成员权限、会话、generation 或服务端控制授权。断线/重置/目标变化中止旧流程。Quick Pair 也必须重新获取合法 Scan 与 Link，不复用过期授权。

POWER 使用电路与断路器图；DOOR 使用舱门与互锁；CAMERA 使用轴与刻度；LIGHT 使用照明驱动；SENSOR 使用热探针；SERVER / NETWORK 使用服务总线。未提供的电压、电流、压力、O₂、CO₂、进程、内存字段明确显示 NOT INSTRUMENTED，不编造遥测或增加不存在的执行器。

控制保留原协议：高影响动作显示依赖集合和 60 秒确认；版本校验、幂等、断线禁控、观察员只读不变。反馈进入细小 SYSTEM MESSAGE 和持久化事件流，删除 Toast 与 `SUCCEEDED // UUID` 弹块。

## 异常与记忆

Alert 为异常分析器：编号、故障源、受影响依赖、接手状态、LOCATE / CAM / SYSTEM LINK / EVENT / ACK。LOCATE 以 Node.module 定位空间舱段，CAM 保持故障目标上下文，SYSTEM LINK 打开专用设备终端。ACK 不消除故障。

Memory Ring 是现有数据的只读关系投影：事件取自服务端保留的日志，SYSTEM 引用统一 Node，关系取自事件 Node ID、模块归属和已有网络/供电边。MEDIA 是原创场景资产引用，不是摄像头录制。没有 AUDIO / CONSTRUCTED 数据时对应过滤不可用；不伪造录音、推理或独立长期记忆。搜索、选中、关系查看与来源定位可用。真实 AI Memory 写入/推理继续属于后续阶段。

## Analog character / 效率

全局轻 scanline、vignette、磷光波动、低强度 grain；Camera 可叠加轻色差与滚动扰动。CRT / VIDEO NOISE / CHROMATIC / GLITCH 均可在设置关闭，CRT 与轻噪声默认开启，扰动和色差默认关闭。减少动态效果时停止装饰周期。

桌面 precise cursor 与手机短暂 touch reticle 不拦截输入。页面以 280ms 线性扫描重绘而非 App 滑动转场；摄像头 HUD 不被大 Panel 遮挡。实际数据和控制不等待装饰动画；首次 Pair 的三步输入可快速完成，后续提供 Quick Pair。
