FROM --platform=linux/arm64 python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /ql

# 基础依赖（Chromium 运行必需）
RUN apt-get update && apt-get install -y \
    wget curl unzip git \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
    libgbm1 libasound2 libxrandr2 libgtk-3-0 \
    fonts-liberation libu2f-udev \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# 安装 Playwright（ARM64 有 wheel）
RUN pip install --no-cache-dir playwright==1.41.2 requests \
    && playwright install chromium

# 安装青龙
RUN wget -O ql.sh https://raw.githubusercontent.com/whyour/qinglong/master/docker/docker.sh \
    && bash ql.sh

EXPOSE 5700

CMD ["./ql.sh"]
