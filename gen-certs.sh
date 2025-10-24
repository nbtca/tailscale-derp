#!/bin/bash
set -e

# 设置域名或IP
DERP_HOST=${1:-"derp.selfhost"}
CERT_DIR="./certs"

# 创建证书目录
mkdir -p ${CERT_DIR}

# 检测输入是IP地址还是域名
# 使用正则表达式匹配IPv4地址
if [[ ${DERP_HOST} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
  SAN_TYPE="IP"
  echo "生成自签名证书，IP地址: ${DERP_HOST}"
else
  SAN_TYPE="DNS"
  echo "生成自签名证书，域名: ${DERP_HOST}"
fi

# 生成私钥
openssl genpkey -algorithm RSA -out ${CERT_DIR}/${DERP_HOST}.key

# 生成CSR (非交互式)
openssl req -new -key ${CERT_DIR}/${DERP_HOST}.key -out ${CERT_DIR}/${DERP_HOST}.csr \
  -subj "/CN=${DERP_HOST}" \
  -addext "subjectAltName=${SAN_TYPE}:${DERP_HOST}"

# 生成自签名证书 (有效期100年)
openssl x509 -req \
  -days 36500 \
  -in ${CERT_DIR}/${DERP_HOST}.csr \
  -signkey ${CERT_DIR}/${DERP_HOST}.key \
  -out ${CERT_DIR}/${DERP_HOST}.crt \
  -extfile <(printf "subjectAltName=${SAN_TYPE}:${DERP_HOST}")

echo "证书生成完成:"
echo "- 证书: ${CERT_DIR}/${DERP_HOST}.crt"
echo "- 私钥: ${CERT_DIR}/${DERP_HOST}.key"
