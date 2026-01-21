#!/bin/bash
set -e

echo "========== 架构检测 =========="
ARCH=$(uname -m)

case "$ARCH" in
  x86_64)
    ARCH_NAME="amd64"
    ;;
  aarch64)
    ARCH_NAME="arm64"
    ;;
  armv7l|armhf)
    ARCH_NAME="arm32"
    ;;
  *)
    echo "⚠️ 未识别架构: $ARCH，尝试继续执行"
    ARCH_NAME="unknown"
    ;;
esac

echo "CPU 架构: $ARCH ($ARCH_NAME)"

echo "========== 安装 Docker =========="

sudo apt-get update -y
sudo apt-get install -y \
  ca-certificates \
  curl \
  gnupg \
  lsb-release

# Docker 官方 GPG
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/$(. /etc/os-release && echo "$ID")/gpg | \
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# ⚠️ 不指定 arch，APT 自动适配 CPU
echo \
  "deb [signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/$(. /etc/os-release && echo "$ID") \
  $(lsb_release -cs) stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update -y
sudo apt-get install -y \
  docker-ce \
  docker-ce-cli \
  containerd.io \
  docker-compose-plugin

sudo systemctl enable docker
sudo systemctl start docker

docker --version
docker compose version

echo "========== 配置青龙 =========="

WORKDIR="$HOME/qinglong"
mkdir -p "$WORKDIR/data"
cd "$WORKDIR"

# 多架构官方镜像（支持 amd64 / arm64 / arm32）
IMAGE="whyour/qinglong:latest"

cat > docker-compose.yml <<EOF
version: "3.8"
services:
  qinglong:
    image: $IMAGE
    container_name: qinglong
    restart: unless-stopped
    ports:
      - "5700:5700"
    volumes:
      - ./data:/ql/data
EOF

echo "========== 启动青龙 =========="
docker compose up -d

echo "========== 安装完成 =========="
echo "架构: $ARCH_NAME"
echo "访问地址: http://<服务器IP>:5700"
