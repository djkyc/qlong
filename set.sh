#!/bin/bash
# ============================================================
# 🧩 青龙面板 Cloudflare 自动部署 + SSL + 智能自动续签 一体脚本
# 作者: djkyc
# ============================================================

# --- 自动检测并修复 Windows (CRLF) 换行符 ---
if file "$0" | grep -q "CRLF"; then
  echo "⚠️ 检测到 Windows (CRLF) 换行符，正在修复自身..."
  if command -v dos2unix >/dev/null 2>&1; then
    dos2unix "$0" >/dev/null 2>&1
  else
    sed -i 's/\r$//' "$0"
  fi
  echo "✅ 修复完成，重新运行脚本..."
  exec bash "$0"
  exit 0
fi

# ============================================================
# 🧾 用户配置区（手动填写以下信息）
# ============================================================

# 提示用户输入 Cloudflare API Token
read -p "请输入你的 Cloudflare API Token: " CF_API_TOKEN

# 提示用户输入 Cloudflare Zone ID
read -p "请输入你的 Cloudflare Zone ID: " CF_ZONE_ID

# 提示用户输入域名
read -p "请输入你的域名（例如 ql.example.com）: " DOMAIN

# 自动检测本机公网 IP，若用户未输入 IP，则使用自动获取的公网 IP
read -p "请输入你的本机公网 IP（按回车跳过，默认自动检测）: " SERVER_IP

# 如果用户未输入公网 IP，则自动检测
if [ -z "$SERVER_IP" ]; then
  SERVER_IP=$(curl -s https://ipinfo.io/ip)
fi

echo "👉 检查并安装依赖..."
apt update -y >/dev/null
apt install -y curl jq nginx certbot python3-certbot-nginx docker.io cron >/dev/null

# 检查必要变量
if [[ -z "$CF_API_TOKEN" || -z "$CF_ZONE_ID" || -z "$DOMAIN" ]]; then
  echo "❌ 请填写 CF_API_TOKEN、CF_ZONE_ID、DOMAIN！"
  exit 1
fi

ROOT_DOMAIN=$(echo "$DOMAIN" | awk -F'.' '{print $(NF-1)"."$NF}')

echo "🌐 域名: $DOMAIN"
echo "📦 Zone ID: $CF_ZONE_ID"
echo "🔑 Token: [已隐藏]"
echo "🌎 公网 IP: $SERVER_IP"
echo "============================="

# === Cloudflare DNS 配置 ===
echo "🌀 检查 Cloudflare DNS 记录..."

EXISTING_DNS=$(curl -s -X GET \
  "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records?type=A&name=$DOMAIN" \
  -H "Authorization: Bearer $CF_API_TOKEN" \
  -H "Content-Type: application/json")

RECORD_ID=$(echo "$EXISTING_DNS" | jq -r '.result[0].id')

if [ "$RECORD_ID" != "null" ]; then
  echo "🔁 更新现有 DNS 记录..."
  curl -s -X PUT \
    "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records/$RECORD_ID" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$SERVER_IP\",\"ttl\":120,\"proxied\":false}" >/dev/null
else
  echo "🆕 创建新的 DNS 记录..."
  curl -s -X POST \
    "https://api.cloudflare.com/client/v4/zones/$CF_ZONE_ID/dns_records" \
    -H "Authorization: Bearer $CF_API_TOKEN" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$DOMAIN\",\"content\":\"$SERVER_IP\",\"ttl\":120,\"proxied\":false}" >/dev/null
fi

echo "✅ DNS 记录配置完成！"

# === 检查 Docker 青龙容器 ===
echo "🐋 检查青龙容器状态..."
if ! docker ps -a --format '{{.Names}}' | grep -q '^qinglong$'; then
  echo "🚀 未检测到青龙容器，正在创建..."
  mkdir -p /ql/config /ql/log /ql/db
  docker run -dit \
    --name qinglong \
    --hostname qinglong \
    --restart unless-stopped \
    -v /ql/config:/ql/config \
    -v /ql/log:/ql/log \
    -v /ql/db:/ql/db \
    -p 5700:5700 \
    whyour/qinglong:latest
elif [ "$(docker inspect -f '{{.State.Running}}' qinglong)" != "true" ]; then
  echo "🟢 启动已存在的青龙容器..."
  docker start qinglong
else
  echo "✅ 青龙容器正在运行。"
fi

# === 临时 HTTP 配置（供证书申请使用） ===
echo "⚙️ 配置临时 Nginx (HTTP)..."

cat >/etc/nginx/conf.d/qinglong.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://127.0.0.1:5700;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

nginx -t && systemctl restart nginx

# === 申请 SSL 证书 ===
echo "🔒 申请 Let's Encrypt 证书..."
certbot certonly --nginx -d "$DOMAIN" --non-interactive --agree-tos -m admin@$ROOT_DOMAIN || {
  echo "❌ 证书申请失败，请检查域名是否正确指向服务器 IP。"
  exit 1
}

# === 完整 HTTPS 配置 ===
echo "🔧 配置正式 HTTPS 反代..."

cat >/etc/nginx/conf.d/qinglong.conf <<EOF
server {
    listen 80;
    server_name $DOMAIN;
    return 301 https://\$host\$request_uri;
}

server {
    listen 443 ssl;
    server_name $DOMAIN;

    ssl_certificate /etc/letsencrypt/live/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/$DOMAIN/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:5700;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF

nginx -t && systemctl reload nginx

# === 自动续签计划任务 ===
echo "🕒 配置自动证书续签任务..."

RENEW_SCRIPT="/usr/local/bin/renew_cert.sh"

cat >"$RENEW_SCRIPT" <<EOF
#!/bin/bash
# ============================================================
# Let's Encrypt 智能续签脚本 (每天凌晨执行)
# ============================================================

DOMAIN="$DOMAIN"
EXPIRY_DATE=\$(date -d "\$(openssl x509 -in /etc/letsencrypt/live/\$DOMAIN/fullchain.pem -noout -enddate | cut -d= -f2)" +%s)
CURRENT_DATE=\$(date +%s)
DAYS_LEFT=\$(( (\$EXPIRY_DATE - \$CURRENT_DATE) / 86400 ))

echo "[\$(date '+%Y-%m-%d %H:%M:%S')] 检查证书有效期: 剩余 \$DAYS_LEFT 天。"

if [ \$DAYS_LEFT -le 7 ]; then
  echo "⚠️ 证书将在 \$DAYS_LEFT 天后过期，正在自动续签..."
  certbot renew --quiet --deploy-hook "systemctl reload nginx"
  echo "✅ 证书续签完成，并已自动重载 nginx。"
else
  echo "✅ 证书仍然有效，无需续签。"
fi
EOF

chmod +x "$RENEW_SCRIPT"

# 每天凌晨2点执行自动检测
(crontab -l 2>/dev/null | grep -v "$RENEW_SCRIPT" ; echo "0 2 * * * $RENEW_SCRIPT >/dev/null 2>&1") | crontab -

systemctl restart cron

echo
echo "✅ 部署完成！"
echo "🌐 访问地址: https://$DOMAIN"
echo "🐋 青龙容器状态: $(docker inspect -f '{{.State.Status}}' qinglong)"
echo "🕒 自动续签任务: 每天凌晨检测证书有效期，如少于7天自动续签并重载 Nginx"
echo "🎉 青龙面板已通过 Cloudflare 域名 + HTTPS 智能维护部署完成！"
echo
