FROM golang:1.25-alpine3.22 AS builder

# 禁用 cgo，强制生成静态二进制，以便在 musl (Alpine) 中运行
ENV CGO_ENABLED=0

# 安装构建时必要的依赖（Alpine）
# git: 用于从模块代理以外获取代码（保底），ca-certificates: HTTPS 模块拉取
RUN apk add --no-cache ca-certificates git

# 直接使用go install安装derper和derpprobe
RUN go install tailscale.com/cmd/derper@latest
RUN go install tailscale.com/cmd/derpprobe@latest

# 第二阶段：最终运行环境
FROM alpine:3.22

# 添加构建参数
ARG DERP_HOST_ARG="derp.selfhost"

# 安装运行时必要组件（Alpine）
RUN apk add --no-cache ca-certificates tzdata

# 从第一阶段拷贝编译好的程序
COPY --from=builder /go/bin/derper /usr/local/bin/derper
COPY --from=builder /go/bin/derpprobe /usr/local/bin/derpprobe

# 创建配置和证书目录
RUN mkdir -p /etc/derper/certs
RUN mkdir -p /var/run/tailscale
RUN mkdir -p /var/lib/derper

# 添加预生成的证书
COPY certs/${DERP_HOST_ARG}.crt /etc/derper/certs/
COPY certs/${DERP_HOST_ARG}.key /etc/derper/certs/

# 创建配置文件默认设置
ENV DERP_HOST=$DERP_HOST_ARG
ENV DERP_PORT=6666
ENV STUN_PORT=7777
ENV HTTP_PORT=-1
ENV VERIFY_CLIENTS=true

# 添加启动脚本
COPY start-derper.sh /usr/local/bin/start-derper.sh
RUN chmod +x /usr/local/bin/start-derper.sh

# 暴露端口
EXPOSE $DERP_PORT/tcp $STUN_PORT/udp

# 设置入口点
ENTRYPOINT ["/usr/local/bin/start-derper.sh"]
