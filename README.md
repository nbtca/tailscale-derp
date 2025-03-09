# 自建 Tailscale DERP 服务器 Docker 镜像

![](https://img.shields.io/badge/LLM-CURSOR-blue)

这个 Docker 镜像用于运行 Tailscale DERP (Designated Encrypted Relay for Packets) 服务器，DERP 是 Tailscale 网络中用于在直接连接失败时中继加密流量的服务。

本项目基于[浅探 Tailscale DERP 中转服务](https://kiprey.github.io/2023/11/tailscale-derp/)一文的内容创建。

## 文件结构

- `Dockerfile` - 构建 Docker 镜像的配置文件
- `docker-compose.yml` - Docker Compose 配置文件
- `start-derper.sh` - DERP 服务器启动脚本
- `gen-certs.sh` - 自签名证书生成脚本
- `certs/` - 预生成的自签名证书目录
- `README.md` - 项目说明文档

## 特点

- 镜像中已包含预生成的自签名证书（域名：`derp.selfhost`）
- 无需额外配置证书即可快速部署
- 内置测试工具`derpprobe`
- 支持客户端验证，防止未授权使用
- 支持在构建时传入自定义主机名

## 使用方法

### 快速开始

使用 Docker 可以快速部署并隔离运行环境，默认使用 `derp.selfhost` 作为主机名，没有开启客户端验证：

```bash
# 构建镜像
docker build -t tailscale-derp .

# 运行容器
docker run -d \
  --name derp-server \
  -p 6666:6666/tcp \
  -p 7777:7777/udp \
  tailscale-derp
```

### 使用自定义主机名构建

您可以在构建镜像时指定自定义的主机名：

```bash
# 首先生成对应域名的证书
./gen-certs.sh your.custom.domain

# 使用自定义主机名构建镜像
docker build -t tailscale-derp --build-arg DERP_HOST_ARG=your.custom.domain .

# 运行容器，确保指定正确的DERP_HOST环境变量
docker run -d \
  --name derp-server \
  -p 6666:6666/tcp \
  -p 7777:7777/udp \
  -e DERP_HOST=your.custom.domain \
  tailscale-derp
```

### 使用 Docker Compose 和自定义主机名

可以通过环境变量在使用Docker Compose时指定自定义主机名：

```bash
# 首先生成对应域名的证书
./gen-certs.sh your.custom.domain

# 设置环境变量并启动
DERP_HOST=your.custom.domain docker-compose up -d
```

### 启用客户端验证

客户端验证功能可以限制只有您自己的 Tailscale 节点才能使用此 DERP 服务器，防止被他人"白嫖"。要启用此功能，需要将宿主机上的 Tailscale socket 文件映射到容器内：

```bash
# 运行带客户端验证的容器
docker run -d \
  --name derp-server \
  -p 6666:6666/tcp \
  -p 7777:7777/udp \
  -e VERIFY_CLIENTS=true \
  -v /var/run/tailscale:/var/run/tailscale \
  tailscale-derp
```

> **注意**：必须在宿主机上安装并运行Tailscale客户端，才能使用此功能。
> 安装Tailscale客户端：
> ```bash
> curl -fsSL https://tailscale.com/install.sh | sh
> tailscale up
> ```

### 自定义证书（可选）

镜像已包含预生成的自签名证书，域名为`derp.selfhost`。如果您需要使用自定义证书，有两种方式：

#### 方式一：构建前生成证书

在构建镜像前，您可以使用提供的脚本生成自定义域名的证书：

```bash
# 使用自定义域名生成证书
./gen-certs.sh your.custom.domain

# 然后构建镜像，指定对应的主机名
docker build -t tailscale-derp --build-arg DERP_HOST_ARG=your.custom.domain .
```

#### 方式二：挂载自定义证书

如果您已有证书，可以在运行容器时挂载目录：

```bash
docker run -d \
  --name derp-server \
  -p 6666:6666/tcp \
  -p 7777:7777/udp \
  -e DERP_HOST="your.custom.domain" \
  -v ${PWD}/certs:/etc/derper/certs \
  -v /var/run/tailscale:/var/run/tailscale \
  tailscale-derp
```

注意：如果挂载证书目录，证书文件名必须与DERP_HOST环境变量一致，例如对于DERP_HOST=example.com，需要有example.com.crt和example.com.key文件。

## 环境变量配置

您可以通过以下环境变量自定义 DERP 服务器配置：

- `DERP_HOST`: DERP 服务器的主机名（默认: derp.selfhost）
- `DERP_PORT`: DERP 服务的 HTTPS 端口（默认: 6666）
- `STUN_PORT`: STUN 服务的 UDP 端口（默认: 7777）
- `HTTP_PORT`: HTTP 端口，设置为 -1 禁用 HTTP（默认: -1）
- `VERIFY_CLIENTS`: 是否验证客户端（默认: false）
  - 设置为 `true` 时，需要将宿主机上的 `/var/run/tailscale` 目录映射到容器中

## 构建参数

在构建镜像时，可以使用以下构建参数：

- `DERP_HOST_ARG`: 自定义DERP服务器的主机名（默认: derp.selfhost）
  - 该值会被设置为容器中的默认`DERP_HOST`环境变量值
  - 构建时会查找对应名称的证书文件（例如：your.domain.crt, your.domain.key）

## 使用 DERP probe 测试

Dockerfile 中已经包含了 `derpprobe` 工具，可以用来测试 DERP 服务器的连通性：

```bash
docker exec -it derp-server derpprobe -derp-map file:///etc/derper/derp-map.json -once
```

测试成功后，您将看到类似以下输出：

```
2025/03/09 14:01:56 good: derp/SELFHOST/derp.selfhost/udp: 483.427µs
2025/03/09 14:01:56 good: derpmap-probe: 5.650528ms
```

## 使用 curl 测试
```bash
export DERP_HOST="derp.selfhost"
export DERP_PUB_IP="233.233.233.233"
export DERP_PUB_PORT=6666
export STUN_PUB_PORT=7777
curl --insecure --resolve "${DERP_HOST}:${DERP_PUB_PORT}:${DERP_PUB_IP}" "https://${DERP_HOST}:${DERP_PUB_PORT}"
nc ${DERP_PUB_IP} ${STUN_PUB_PORT} -v -u
```

## Tailscale ACL 配置

```bash
docker cp derp-server:/etc/derper/derp-map.json ./derp-map.json
```
修改 `derp-map.json` 文件中的 `127.0.0.1` 为您的 DERP 服务器 IP 地址

官方默认的 DERP 服务器列表：
https://controlplane.tailscale.com/derpmap/default

在您的 Tailscale 管理后台中，修改 ACL 规则中 `derpMap` 的配置：

```
"derpMap": {
  //"OmitDefaultRegions": true,
  // 下面是 derp-map.json 文件内容，请根据实际情况修改 127.0.0.1 为您的 DERP 服务器 IP 地址
  "Regions": {
    "999": {
      "RegionID": 999,
      "RegionCode": "SELFHOST",
      "Nodes": [
        {
          "Name": "derp.selfhost",
          "RegionID": 999,
          "HostName": "derp.selfhost",
          "IPv4": "127.0.0.1",
          "DERPPort": 6666,
          "STUNPort": 7777,
          "InsecureForTests": true
        }
      ]
    }
  }
}
```

然后在其它 Tailscale 节点中检查是否能正常连接：

```
tailscale netcheck
```
你会看到类似以下输出：

```
Report:
        * Time: 2025-03-09T14:04:05.719200078Z
        * UDP: true
        * IPv4: yes, 233.233.233.233:2333
        * IPv6: no, but OS has support
        * MappingVariesByDestIP:
        * PortMapping: UPnP, NAT-PMP, PCP
        * CaptivePortal: false
        * Nearest DERP:
        * DERP latency:
                - SELFHOST: 9.3ms   ()
```

## Aliyun Docker 中转
```bash
# 国外主机构建
docker login registry.cn-hongkong.aliyuncs.com
docker tag tailscale-derp registry.cn-hongkong.aliyuncs.com/<namespace>/tailscale-derp:latest
docker push registry.cn-hongkong.aliyuncs.com/<namespace>/tailscale-derp:latest
# 国内主机拉取
docker pull registry.cn-hongkong.aliyuncs.com/<namespace>/tailscale-derp:latest
docker tag registry.cn-hongkong.aliyuncs.com/<namespace>/tailscale-derp:latest tailscale-derp:latest
docker rmi registry.cn-hongkong.aliyuncs.com/<namespace>/tailscale-derp:latest
```

## 参考资料

- [浅探 Tailscale DERP 中转服务](https://kiprey.github.io/2023/11/tailscale-derp/) - Kiprey's Blog
- [DERP Servers - Tailscale Documentation](https://tailscale.com/kb/1118/custom-derp-servers/)
