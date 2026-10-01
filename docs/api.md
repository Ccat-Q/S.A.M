# API 与同步契约

REST `/api/*` 和 WebSocket `/api/stream` 使用 `Authorization: Bearer <opaque-token>`；令牌随机生成，数据库仅保存 SHA-256 摘要。所有响应 no-store。HTTPS/WSS 由 Cloudflare 公网入口提供。客户端仅 CI 模式允许 localhost HTTP。

OpenAPI 在每次成功 CI 中生成并附于 `ubuntu-server` 产物。请求结构以 Pydantic schemas 为来源。

| 接口 | 行为 |
| --- | --- |
| POST /api/auth/login | username/password，返回 token、expires_at、user |
| GET /api/auth/me；POST /api/auth/logout | 当前成员、撤销会话与 Link |
| GET /api/snapshot | nodes、edges、camera_targets、alerts、generation、tick、paused、cursor |
| GET /api/nodes/{id}；POST /api/nodes/{id}/scan | 查询身份/能力；扫描另返回绑定当前成员会话的 scan_id，5 分钟有效 |
| POST /api/links；DELETE /api/links/{id} | node_id/generation/scan_id，创建或撤销当前登录会话所属 Link |
| POST /api/commands/prepare | 返回 confirmation_id、expires_at、affected_nodes |
| POST /api/commands | node_id、link_id、action、value、expected_version、key、可选 confirmation_id |
| GET /api/commands/by-key/{key} | 查询本成员命令结果，供超时恢复 |
| POST /api/alerts/{id}/acknowledge | 记录接手成员，不清除故障 |
| GET /api/logs | q、category、node_id、before、since、until、limit；时间含时区 |
| GET/POST /api/members；PATCH /api/members/{id} | 管理员成员管理 |
| POST /api/simulation | action：pause/resume/reset/scenario |
| POST /api/simulation/fault | 管理员指定节点故障或清除 |

节点控制版本仅在控制相关状态改变时推进；遥测变化不推进。命令幂等范围是成员+key，重复 key 改参数返回 409。高影响确认绑定动作、Link、设施 generation 及所有影响节点版本；过期/改变后必须重新确认。

## WebSocket

客户端先取得一致快照，然后连接 `/api/stream?after={cursor}`。服务器发 `{"type":"events","cursor":N,"events":[...]}`，事件含 cursor/time/category/message/node_id/actor/correlation_id/data。

data.nodes 为节点替换补丁；data.alerts 为告警列表；data.generation / paused / tick 更新设施元信息。事件仅在事务提交后可见；状态快照通过共享设施锁保证游标与状态一致。

游标超出范围或早于保留窗口时返回 `{"type":"snapshot","snapshot":...}`。客户端接受完整状态后继续同步。每秒包允许为空以检查连接；数据库有序事件是重放来源，五人规模不需要额外消息代理。

REST 快照和推送可能交错：已包含在快照游标中的事件仍可补齐日志，但不得回退节点、告警和游标；日志按游标去重，节点补丁不能覆盖较新的控制版本。新的 generation 重置旧 Link，并允许节点版本重新从 1 开始。服务端明确返回的恢复快照可替换整个状态；主动重连先清除客户端旧授权。

401 / WebSocket 4401 表示需要重新登录；403 为权限拒绝；409 为 Link、版本、确认或幂等冲突；422 为参数不合法。客户端对 409 刷新必要状态，不静默重试高影响动作。

## 客户端接入呈现

第二轮的 Pair 符号序列和 Quick Pair 仅改变客户端交互；Scan 凭据、会话/成员绑定 Link、状态版本、幂等、影响确认及权限检查协议不变。Memory Ring 通过现有日志、快照 Node 和 edges 构建只读关系投影，不引入记忆写接口。
