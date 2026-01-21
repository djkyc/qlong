ARG TARGETPLATFORM
FROM python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive
WORKDIR /ql

# Chromium 运行依赖
RUN apt-get update && apt-get install -y \
    curl wget unzip git ca-certificates \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 \
    libdrm2 libxkbcommon0 libxcomposite1 libxdamage1 libxfixes3 \
    libgbm1 libasound2 libxrandr2 libgtk-3-0 \
    fonts-liberation libu2f-udev \
    && rm -rf /var/lib/apt/lists/*

# Playwright + Chromium（ARM64）
RUN pip install --no-cache-dir playwright==1.41.2 requests \
 && playwright install chromium

# 安装青龙（稳定版）
RUN curl -fsSL --retry 5 --retry-delay 3 \
    https://raw.githubusercontent.com/whyour/qinglong/master/docker/docker.sh \
    -o ql.sh \
 && chmod +x ql.sh \
 && bash ql.sh

EXPOSE 5700
CMD ["./ql.sh"]
