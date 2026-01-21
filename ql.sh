#!/bin/bash
set -e

echo "=============================="
echo " 青龙 Docker 多架构安装脚本 "
echo "=============================="

# ----------------------------
# 1. 检测系统架构
# ----------------------------
ARCH=$(uname -m)

case "$ARCH" in
  x86_64)
    DOCKER_PLATFORM="linux/amd64"
    ;;
  aarch64)
    DOCKER_PLATFORM="linux/arm64"
    ;;
  armv7l)
    DOCKER_PLATFORM="linux/arm/v7"
    ;;
  *)
    echo "❌ 不支持的架构: $ARCH"
    exit 1
    ;;
esac

echo "✅ 检测到系统架构: $ARCH -> $DOCKER_PLATFORM"

# ----------------------------
# 2. 安装 Docker
# ----------------------------
echo "👉 安装 Docker..."

sudo apt-get update -y
sudo apt-get install -y \
  apt-transport-https \
  ca-certificates \
  curl \
  software-properties-common \
  jq

curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] \
https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" \
| sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# ----------------------------
# 3. 安装 Docker Compose（v1 兼容版）
# ----------------------------
echo "👉 安装 Docker Compose..."

sudo curl -L \
"https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" \
-o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

docker --version
docker-compose --version

# ----------------------------
# 4. 创建工作目录
# ----------------------------
WORKDIR="$HOME/ql_data"
mkdir -p "$WORKDIR/data"

# ----------------------------
# 5. 生成 docker-compose.yml（多架构）
# ----------------------------
echo "👉 生成 docker-compose.yml"

cat > "$WORKDIR/docker-compose.yml" <<EOF
version: '3.8'
services:
  qinglong:
    image: ghcr.io/djkyc/qinglong:latest
    container_name: qinglong
    platform: ${DOCKER_PLATFORM}
    restart: always
    volumes:
      - ${WORKDIR}/data:/ql/data
    ports:
      - "5700:5700"
    environment:
      - PM2_HOME=/root/.pm2
    networks:
      - ql_network

networks:
  ql_network:
    driver: bridge
EOF

# ----------------------------
# 6. 启动容器
# ----------------------------
echo "👉 启动青龙容器..."
cd "$WORKDIR"
docker-compose up -d

# ----------------------------
# 7. 完成提示
# ----------------------------
echo "=============================="
echo " 🎉 青龙安装完成！"
echo " 架构: $DOCKER_PLATFORM"
echo " 访问地址: http://<你的服务器IP>:5700"
echo "=============================="
