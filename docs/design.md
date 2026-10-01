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
6. **MEMORY CORE**：以 MEMORY CORE 为中心索引的径向关系场。外围显示现有事件、节点状态引用和场景媒体引用；选中节点放大并显示有真实数据依据的彩色关系。

## Tokens / 字体 / 导航

`client/lib/ui/theme.dart` 的 `SamTokens` 管理背景、面板底色、磷光、文字、暗色、细线、琥珀、蓝色、告警、线宽和效果强度。设备通过局部 accent 覆盖颜色：POWER 琥珀，ENVIRONMENT 淡绿，SERVER / NETWORK 蓝色，CAMERA 白色。

背景 #050708 / #0B0E0F，文字 #D8E2DF，淡青主色。主色是项目选择，不声称来自原作取色。读数 Roboto Mono，系统标题 Roboto Condensed，保留系统中文 fallback；使用 [Google Fonts 官方仓库](https://github.com/google/fonts) 的 SIL OFL 字体，许可证打包进应用。

系统代码为英文，中文辅助解释；状态保留 ONLINE / OFFLINE / ESTABLISHED / NOMINAL / FAULT。标题通常 13–18 逻辑像素，辅助读数 8–12；细小视觉不缩小触控命中区域，交互至少 44 逻辑像素。

顶栏为小型 `SAM.OS / REV`、持续递增的实际会话 uptime、状态及 `SYSTEM / RELOC / NETWORK / ALERT / MEMORY` 一级模块 Tab。底部只承载当前页面的操作，不重复导航：SYSTEM 为 DETAIL / LOG / DIAG / RELOC / COMMAND，RELOC 为 SELECT / CAMERA / TRACE / FILTER / RETURN，CAMERA 为 ANGLE / SCAN / LINK / TRACK / EXIT，ALERT 为 LOCATE / CAMERA / LINK / ACK / HISTORY，MEMORY 为 OPEN / RELATE / FILTER / TRACE / RETURN。COMMAND 索引保留设备、日志、设置等既有入口。没有大图标、胶囊高亮、Material Navigation 或圆角 Bottom Sheet。平板沿用终端语言，控制覆盖层靠右；手机控制覆盖层靠下，可滚动。

## 感知与连接链

RELOCATION → MODULE SELECT → CAMERA → TARGET → SCAN → IDENTIFY → PAIR → LINK → DEVICE INTERFACE。

Module Select 显示模块名称、状态、相机缩略图、可用视角以及 RELOCATE。点击站体不会直接弹出设备资产表。内部设备层与独立 Network 仍提供已知节点检查，保证既有设备管理能力可达。

摄像头目标默认只显示微小点；瞄准后出现准星和 TARGET CANDIDATE，扫描后在 Feed 内展示身份，LINK 才进入设备终端。场景与命中区域使用同一 pan / tilt / zoom 变换，切换相机使用短扫描重绘。离线显示 NO SIGNAL；不能假装有视觉。告警已知的上游故障设备允许从此上下文进入总线 System Link，以恢复供电；仍须服务端 SCAN 和 Link 校验。

Pair 首次显示三个随机符号，按提示触摸完成，正常约 2–3 秒；错误只重置输入，不发送 Link 请求。已完成的界面可 Quick Pair。它是客户端接入表现，不是认证因子，不替代扫描凭据、成员权限、会话、generation 或服务端控制授权。断线/重置/目标变化中止旧流程。Quick Pair 也必须重新获取合法 Scan 与 Link，不复用过期授权。

POWER 使用电路与断路器图；DOOR 使用舱门与互锁；CAMERA 使用轴与刻度；LIGHT 使用照明驱动；SENSOR 使用热探针；SERVER / NETWORK 使用服务总线。未提供的电压、电流、压力、O₂、CO₂、进程、内存字段明确显示 NOT INSTRUMENTED，不编造遥测或增加不存在的执行器。

控制保留原协议：高影响动作显示依赖集合和 60 秒确认；版本校验、幂等、断线禁控、观察员只读不变。反馈进入细小 SYSTEM MESSAGE 和持久化事件流，删除 Toast 与 `SUCCEEDED // UUID` 弹块。

## 异常与记忆

Alert 为异常分析器：编号、故障源、受影响依赖、接手状态、LOCATE / CAM / SYSTEM LINK / EVENT / ACK。LOCATE 以 Node.module 定位空间舱段，CAM 保持故障目标上下文，SYSTEM LINK 打开专用设备终端。ACK 不消除故障。

Memory Ring 是现有数据的只读关系投影：事件取自服务端保留的日志，SYSTEM 引用统一 Node，关系取自事件 Node ID、模块归属和已有网络/供电边。VISUAL 是原创场景资产引用，不是摄像头录制。CONSTRUCTED 为模块成员关系的确定性投影，并非 AI 推理；没有 AUDIO 数据时对应过滤不可用；不伪造录音、推理或独立长期记忆。搜索、选中、关系查看与来源定位可用。真实 AI Memory 写入/推理继续属于后续阶段。

## Analog character / 效率

全局轻 scanline、vignette、磷光波动、低强度 grain；Camera 可叠加轻色差与滚动扰动。CRT / VIDEO NOISE / CHROMATIC / GLITCH 均可在设置关闭，CRT 与轻噪声默认开启，扰动和色差默认关闭。减少动态效果时停止装饰周期。

桌面 precise cursor 与手机短暂 touch reticle 不拦截输入；手机准星为淡磷光细线，触摸后 450ms 消失。页面以 280ms 线性扫描重绘而非 App 滑动转场；Overview 图层以 20/40/70/110ms 起始偏移，在 380ms 内完成绘制。摄像头 HUD 不被大 Panel 遮挡。实际数据和控制不等待装饰动画；首次 Pair 的三步输入可快速完成，后续提供 Quick Pair。

## 运行感修订

保留现有线框与黑场。新增 airlock、utility arm、relay、service tunnel、外部供电结构作为原创设施几何，不能冒充新增的在线 Node。站体低幅中心脉冲、线路移动光点、摄像机位置亮度变化由独立绘制层驱动；暂停模拟时停下线路移动。遵循系统减少动态效果设置。

Overview 额外显示真实 SEN-01 温度、NET-01 上行状态与 Sensor 集合状态，不编造 LOAD、O₂ 或模型运行状态。SYS.AI / WATCH MODE 表示 Mock 监测模式，不表示已接入模型。

Event Stream 是最多四条的客户端实时队列，来源为服务端 WebSocket 事件；每三个遥测 tick 呈现一帧，其他实际事件立即进入。界面显示最近三条及真实时间，旧条目通过短距离滚动、透明度衰减退出。重置、登出清空队列，重复 cursor 去重；持久审计和日志仍由原服务提供。暂停/断线不会继续制造正常遥测事件。

Alert 无异常时显示 ARMED / STALE、ALERT REGISTER / 000 / NO ACTIVE EXCEPTIONS、监测节点数和 Watch Channels，背景为极淡事件轴、刻度和模块参考线；有异常时替换为故障源及依赖分析。ACK 仍不等于恢复。

Camera 老旧 CCTV 效果仅作用于光学画面：轻度去饱和、场扫描线、曝光缓慢波动、低对比 field ghost 与压缩颗粒。HUD 文字不做字符替换或失真。TRACK 是当前目标的手动锁定/释放，阻止误选；没有自动目标检测、实体追踪或虚构运动轨迹。

## 操作层级与工程子系统（2026-10-01）

SYSTEM OVERVIEW 冻结。本轮不改变其构图、设施几何、全局配色、字体或 CRT 基础，仅修复 Event Stream 的高度溢出。

Shell 保留现有页面与单一 SystemStore，不新增路由或权限状态。LEVEL 0/1 为 OS 与模块；LEVEL 2 的 Optical、选中 Memory Node、Alert Detail 收起一级导航并使用 28px 状态栏；退出操作恢复模块导航。LEVEL 3 是完整设备终端，无一级导航。它是显示深度而非权限等级。

Camera 的 Feed 为主体，光学 Channel Selector 显示 A ACTIVE / B STANDBY / C N/A；切换按 SIGNAL DROP → STATIC → SYNC → LOCK → VIDEO RESTORE，在 260ms 内完成。进入光学页面不继承其他页面的识别结果，只有本次瞄准并成功取得服务端 Scan receipt 后显示身份。SCAN 不打开设备终端；LINK 打开 Pair / HANDSHAKE / AUTH / CHANNEL，实际授权仍来自服务端。离线时仍可按已知故障上下文恢复上游设备，不能声称有视觉识别。

微小标记为默认；触摸准星 500ms，扫描时白色，手动锁定时持续。镜头网格与命中区域共享轻度径向畸变、pan/tilt/zoom；轻软焦、暗噪、曝光呼吸与边缘衰减仅影响 Feed，不影响 HUD。沿用现有 CRT / NOISE / CHROMATIC / GLITCH 开关和减少动态效果设置。识别并非真实 AI，CONF 显示 NOT SCORED。

Alert Register 的 ACTIVE/QUEUE/UNACK 与历史独立。右侧 TIME × MODULE 矩阵展示真实模拟异常及三条明确标注 MOCK_HISTORY 的已解决种子事件，事件符号支持选择、详情和来源操作。模拟历史一次性添加到已有场景，不覆盖旧事件、故障或审计；重启不重复添加，Reset 保留历史，保留策略继续生效。resolved 为低亮灰色，未解决 warning/critical 使用现有 amber/red。最后 Soft Key 始终 HISTORY；详情另提供 OPEN AUDIT LOG。

Memory 分类为 EVENT、OBSERVATION（设备识别审计）、SYSTEM（实时节点）、VISUAL（原创 Mock 资产）、FRAGMENT（安全事件片段）、CONSTRUCTED（模块成员投影），AUDIO 保留不可用状态。选中节点后 260ms 重排并高亮已有关系，RETURN 先返回 Memory 模块。元数据含 ID、来源、时间、类型、节点、关系数和置信度；没有源评分时明确 NOT SCORED。没有新增 AI 模型或独立长期记忆写入服务。
