构建 & 运行（ARM64 主机）
docker build -t ql-arm-playwright .

docker run -d \
  --name qinglong \
  -p 5700:5700 \
  -v /ql/data:/ql/data \
  ql-arm-playwright


浏览器访问：

http://IP:5700
