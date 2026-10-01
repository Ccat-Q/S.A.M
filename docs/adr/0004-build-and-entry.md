# GitHub Actions 构建与 Cloudflare Tunnel 入口

按用户约束，所有编译与自动化验证放在 GitHub Actions，仅交付未签名 IPA 和 Ubuntu 镜像包。Flutter 原生平台模板由固定 SDK 在 CI 生成，项目特有配置由版本化脚本施加，生成项目随产物交付；避免手写 Xcode 模板。Cloudflare Tunnel 提供 HTTPS 入口而无需开放源站端口，成员权限仍由应用管理，不将入口凭据作为成员身份。
