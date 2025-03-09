#!/bin/sh

# 检查客户端验证
if [ "$VERIFY_CLIENTS" = "true" ]; then
  # 检查socket文件是否存在
  if [ -S "/var/run/tailscale/tailscaled.sock" ]; then
    echo "启用客户端验证 (找到tailscaled.sock)"
    VERIFY_FLAG="--verify-clients"
  else
    echo "警告: 找不到tailscaled.sock，客户端验证已禁用"
    VERIFY_FLAG=""
  fi
else
  VERIFY_FLAG=""
fi

# 设置DERP Map配置参数
REGION_ID=${REGION_ID:-"999"}
REGION_CODE=${REGION_CODE:-"SELFHOST"}
DERP_NAME=${DERP_NAME:-"${DERP_HOST}"}
SERVER_IPV4=${SERVER_IPV4:-"127.0.0.1"}
DERP_MAP_PATH=${DERP_MAP_PATH:-"/etc/derper/derp-map.json"}

# 生成DERP Map配置文件
cat > ${DERP_MAP_PATH} << EOF
{
  "Regions": {
    "${REGION_ID}": {
      "RegionID": ${REGION_ID},
      "RegionCode": "${REGION_CODE}",
      "Nodes": [
        {
          "Name": "${DERP_NAME}",
          "RegionID": ${REGION_ID},
          "HostName": "${DERP_HOST}",
          "IPv4": "${SERVER_IPV4}",
          "DERPPort": ${DERP_PORT},
          "STUNPort": ${STUN_PORT},
          "InsecureForTests": true
        }
      ]
    }
  }
}
EOF

echo "已生成DERP Map配置文件: ${DERP_MAP_PATH}, 请在 Tailscale ACL 中使用此配置"

# 启动DERP服务
echo "启动DERP服务: ${DERP_HOST}:${DERP_PORT}"
echo "证书文件: /etc/derper/certs/${DERP_HOST}.crt, /etc/derper/certs/${DERP_HOST}.key"
echo "参数: -a :${DERP_PORT} -http-port ${HTTP_PORT} -stun-port ${STUN_PORT} -hostname ${DERP_HOST} -certmode manual -certdir /etc/derper/certs ${VERIFY_FLAG}"

exec /usr/local/bin/derper \
  -a :${DERP_PORT} \
  -http-port ${HTTP_PORT} \
  -stun-port ${STUN_PORT} \
  -hostname ${DERP_HOST} \
  -certmode manual \
  -certdir /etc/derper/certs \
  ${VERIFY_FLAG}
