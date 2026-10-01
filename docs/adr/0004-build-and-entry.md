# GitHub Actions 构建与 Cloudflare Tunnel 入口

按用户约束，所有编译与自动化验证放在 GitHub Actions，仅交付未签名 IPA 和 Ubuntu 镜像包。Flutter 原生平台模板由固定 SDK 在 CI 生成，项目特有配置由版本化脚本施加，生成项目随产物交付；避免手写 Xcode 模板。Cloudflare Tunnel 提供 HTTPS 入口而无需开放源站端口，成员权限仍由应用管理，不将入口凭据作为成员身份。

补充：为满足约 10 分钟、最多 15 分钟的运行预算，服务端、设备版构建和模拟器验收并行；共享本地 composite action 配置缓存和原生策略。验收失败不伪装成功，也不阻止独立构建生成可审阅 IPA。SDK/Pub 提前保存，原生缓存分用途，整轮 deadline 在 14 分钟强制停止未完成工作。
