# Ubuntu / Cloudflare 手动部署

## 准备

Ubuntu 24.04 LTS（amd64）、Docker Engine + Compose 插件、已由 Cloudflare 托管的域名。下载同一次成功 Actions 的 `ubuntu-server` 产物，保留 COMMIT 与校验文件。

```sh
sha256sum -c SHA256SUMS
docker load -i sam-server.tar.gz
cd deploy
cp .env.example .env
chmod 600 .env
```

校验文件使用产物文件名，在包含镜像的解压目录执行。设置 `.env`：POSTGRES_PASSWORD 使用 URL-safe 随机值（例如 `openssl rand -hex 32`）；TUNNEL_TOKEN 使用你创建的 tunnel token；SAM_IMAGE 使用 `sam-server:<COMMIT>`，避免运行未知 latest。

## 入口与首次启动

在 Cloudflare 创建 Tunnel 和发布路由，例如 `sam.your-domain.example` → `http://api:8000`。DNS/路由由用户手动配置。该 hostname 不得应用会替换 API JSON 的交互式挑战或未经设计的 Access 登录页；成员认证由 S.A.M. 服务端负责。不要把 Tunnel token 放入 App。

Compose 不向公网发布 PostgreSQL 或 API 端口。cloudflared 和 API 在同一私有 Docker 网络。

```sh
docker compose up -d
docker compose exec api sam-admin your_admin_name
docker compose logs --tail 100 api
```

CLI 交互输入 12–128 位密码，无默认管理员。客户端填写 HTTPS hostname 并登录，管理员在设置中创建操作员和观察员。

API 只能运行一个实例、一个 worker，模拟器由该实例管理。增设副本前必须拆出唯一模拟器并设计推送协调，本阶段不可简单增加 workers。

## 更新、备份及回退

更新前保存原镜像标签，并备份数据库：

```sh
docker compose exec -T database pg_dump -U sam -d sam -Fc > sam-backup.dump
docker load -i ../sam-server.tar.gz
# 将 .env 的 SAM_IMAGE 改为新提交标签
docker compose up -d
```

迁移服务成功后 API 才启动。保留备份和旧镜像；回退前先检查迁移兼容性，不能仅用旧镜像读新结构。当前 0001 为初始迁移。恢复时先停止 API/migrate/tunnel，再用 pg_restore 恢复兼容数据库，重新启动。恢复练习必须在隔离设施上进行。

日志默认 30 天，审计/命令/告警 90 天，通过 SAM_LOG_RETENTION_DAYS 和 SAM_AUDIT_RETENTION_DAYS 调整。密码、数据库备份和 Tunnel token 不得提交 Git。

## iOS 产物

`ios-client` 含 sam-unsigned.ipa、内容清单、校验文件及生成的原生项目。IPA 按 Payload/SAM.app 打包，包含 arm64 设备可执行文件；后续签名时保留/替换匹配的 Keychain entitlements。未签名包不能直接作为普通 iPhone 可安装应用。

签名、证书、设备描述文件和安装由用户处理；本仓库没有 Apple 私钥。正常客户端仅允许 HTTPS；开发 CI localhost 例外不会进入 release 配置。
