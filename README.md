# 青龙 + Cloudflare 一键部署脚本

> ⚡ 本项目提供一键部署青龙面板 + Cloudflare + 自动续签证书的脚本，支持原版和 CDN 加速版。

---

## 🚀 一键部署命令


1️⃣ 原版命令（raw.githubusercontent）
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/dj56959566/qlong/refs/heads/main/set.sh)
💡 原版命令直接从 GitHub 官方下载，适合海外或网络稳定的用户。
```
2️⃣ CDN 加速版本命令（国内访问更快）
```bash
bash <(curl -fsSL https://cdn.jsdelivr.net/gh/dj56959566/qlong@main/set.sh)
💡 加速版本使用 JSDelivr 的 GitHub CDN，下载速度更快、更稳定，适合国内用户。
```
🧩 新增功能

✅ 在前一个版本基础上新增：

自动配置 certbot 定时任务（cron）

证书到期前 7 天自动续签

自动重载 nginx

自动检测并修复 Windows 换行符

自动安装依赖、配置 Cloudflare、启动青龙容器、申请/续签证书、反向代理一体完成


| 模块                | 功能                                |
| ----------------- | --------------------------------- |
| 💡 自动修复换行符        | 避免 `^M` 报错                        |
| 🔧 自动安装依赖         | `nginx`、`certbot`、`docker`、`cron` |
| 🌍 Cloudflare DNS | 自动创建/更新 A 记录                      |
| 🐋 Docker 青龙      | 自动创建或启动容器                         |
| 🔒 SSL 证书         | 自动申请/部署 HTTPS                     |
| 🔁 自动续签           | 每天凌晨检测，如到期前 7 天自动续签并重载 nginx      |

⚙️ #使用方法
chmod +x set.sh
bash set.sh


然后在脚本顶部填写：

CF_API_TOKEN="你的_CF_Token"

CF_ZONE_ID="你的_Zone_ID"

DOMAIN="ql.yourdomain.com"


（SERVER_IP 可留空自动检测）
