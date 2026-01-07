#!/bin/bash

# 安装 Docker 和 Docker Compose
echo "安装 Docker 和 Docker Compose..."

# 更新软件包
sudo apt-get update -y

# 安装依赖
sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common

# 添加 Docker 官方 GPG 密钥
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

# 设置 Docker 仓库
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# 更新软件包列表并安装 Docker
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# 安装 Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/download/$(curl -s https://api.github.com/repos/docker/compose/releases/latest | jq -r .tag_name)/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# 验证 Docker 和 Docker Compose 安装
docker --version
docker-compose --version

# 创建并配置工作目录
echo "配置工作目录..."

# 设置数据存储目录
WORKDIR="$HOME/ql_data"
mkdir -p $WORKDIR

# 使用自定义镜像并配置 Docker Compose
echo "使用自定义镜像 'ghcr.io/djkyc/qinglong:latest' 配置 Docker Compose..."

cat > $WORKDIR/docker-compose.yml <<EOF
version: '3'
services:
  qinglong:
    image: ghcr.io/djkyc/qinglong:latest
    container_name: qinglong
    restart: always
    volumes:
      - $WORKDIR/data:/ql/data  # 数据挂载
    ports:
      - "5700:5700"  # 公开端口
    environment:
      - PM2_HOME=/root/.pm2
    networks:
      - ql_network
networks:
  ql_network:
    driver: bridge
EOF

# 启动容器
echo "启动青龙容器..."
cd $WORKDIR
docker-compose up -d

# 提示安装完成
echo "青龙 Docker 安装完成！"
echo "你可以通过浏览器访问：http://<your-server-ip>:5700 来访问青龙面板。"
