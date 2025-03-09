#!/bin/bash
set -e

# 设置域名
DERP_HOST=${1:-"derp.selfhost"}
CERT_DIR="./certs"

# 创建证书目录
mkdir -p ${CERT_DIR}

echo "生成自签名证书，域名: ${DERP_HOST}"

# 生成私钥
openssl genpkey -algorithm RSA -out ${CERT_DIR}/${DERP_HOST}.key

# 生成CSR (非交互式)
openssl req -new -key ${CERT_DIR}/${DERP_HOST}.key -out ${CERT_DIR}/${DERP_HOST}.csr \
  -subj "/CN=${DERP_HOST}" \
  -addext "subjectAltName=DNS:${DERP_HOST}"

# 生成自签名证书 (有效期100年)
openssl x509 -req \
  -days 36500 \
  -in ${CERT_DIR}/${DERP_HOST}.csr \
  -signkey ${CERT_DIR}/${DERP_HOST}.key \
  -out ${CERT_DIR}/${DERP_HOST}.crt \
  -extfile <(printf "subjectAltName=DNS:${DERP_HOST}")

echo "证书生成完成:"
echo "- 证书: ${CERT_DIR}/${DERP_HOST}.crt"
echo "- 私钥: ${CERT_DIR}/${DERP_HOST}.key"
