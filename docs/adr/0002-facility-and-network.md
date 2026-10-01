# 空间地图与依赖地图分开

原作 Relocation Map 主要表达空间舱段，而运维平台需要通信和供电依赖。选择 FACILITY/NETWORK 双视图共享 Node ID，而不将空间邻近与网络连接混作同一种线路，避免错误诊断，同时保持告警、摄像头和控制上下文一致。

第二轮修订：按用户要求，从同页双视图拆为独立 RELOCATION / NETWORK 模块。RELOCATION 首层站体与模块，内部层设备；NETWORK 专门显示通信和供电依赖。Node ID 与告警上下文继续共享。详见 ADR 0005。
