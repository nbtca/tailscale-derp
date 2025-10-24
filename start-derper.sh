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

# 如果证书文件不存在，尝试生成并复制到 /etc/derper/certs
# 优先使用仓库中的 ./certs/${DERP_HOST}.crt/.key，如果不存在则调用 ./gen-certs.sh
CERT_NAME="${DERP_HOST:-derp.selfhost}"
REPO_CERT_DIR="./certs"
REPO_CERT="${REPO_CERT_DIR}/${CERT_NAME}.crt"
REPO_KEY="${REPO_CERT_DIR}/${CERT_NAME}.key"
SYSTEM_CERT_DIR="/etc/derper/certs"
SYSTEM_CERT="${SYSTEM_CERT_DIR}/${CERT_NAME}.crt"
SYSTEM_KEY="${SYSTEM_CERT_DIR}/${CERT_NAME}.key"

if [ ! -f "${SYSTEM_CERT}" ] || [ ! -f "${SYSTEM_KEY}" ]; then
  echo "证书或私钥未找到: ${SYSTEM_CERT} 或 ${SYSTEM_KEY}"
  # 如果仓库中已有证书则复制过去
  if [ -f "${REPO_CERT}" ] && [ -f "${REPO_KEY}" ]; then
    echo "从仓库证书复制到 ${SYSTEM_CERT_DIR}"
    mkdir -p "${SYSTEM_CERT_DIR}"
    cp "${REPO_CERT}" "${SYSTEM_CERT}"
    cp "${REPO_KEY}" "${SYSTEM_KEY}"
    chmod 644 "${SYSTEM_CERT}"
    chmod 600 "${SYSTEM_KEY}"
  elif [ -x "/usr/local/bin/gen-certs.sh" ]; then
    echo "调用 /usr/local/bin/gen-certs.sh 生成证书: ${CERT_NAME}"
    /usr/local/bin/gen-certs.sh "${CERT_NAME}"
  elif [ -x "./gen-certs.sh" ] || [ -f "./gen-certs.sh" ]; then
    echo "调用 ./gen-certs.sh 生成证书: ${CERT_NAME}"
    ./gen-certs.sh "${CERT_NAME}"
    if [ -f "${REPO_CERT}" ] && [ -f "${REPO_KEY}" ]; then
      mkdir -p "${SYSTEM_CERT_DIR}"
      cp "${REPO_CERT}" "${SYSTEM_CERT}"
      cp "${REPO_KEY}" "${SYSTEM_KEY}"
      chmod 644 "${SYSTEM_CERT}"
      chmod 600 "${SYSTEM_KEY}"
    else
      echo "错误: gen-certs.sh 未能生成预期的证书文件 (${REPO_CERT}, ${REPO_KEY})"
      exit 1
    fi
  else
    echo "错误: 未找到证书，也没有可用的 gen-certs.sh 来生成证书。"
    exit 1
  fi
else
  echo "证书已存在: ${SYSTEM_CERT}"
fi

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
