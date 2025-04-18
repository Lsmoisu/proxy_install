#!/bin/bash

# Hysteria安装和配置脚本（已添加自定义端口选项）
# 作者：Grok3
# 描述：自动安装Hysteria服务、生成证书、配置并重启服务，支持自定义端口。
# 注意：请以root权限运行此脚本。

# 步骤1: 提示用户输入自定义端口（默认20000）
read -p "请输入Hysteria监听端口（默认: 20000, 范围: 1-65535）: " user_port

# 如果未输入，使用默认端口
if [ -z "$user_port" ]; then
    user_port=20000
fi

# 简单验证端口是否为有效的数字
if ! [[ "$user_port" =~ ^[0-9]+$ ]] || [ "$user_port" -lt 1 ] || [ "$user_port" -gt 65535 ]; then
    echo "错误: 端口必须是1-65535之间的有效数字。"
    exit 1
fi

echo "您设置的端口是: $user_port"

# 步骤2: 提示用户输入密码
read -p "请输入Hysteria配置密码（用于auth部分）: " user_password

if [ -z "$user_password" ]; then
    echo "错误: 密码不能为空，请重新运行脚本。"
    exit 1
fi

echo "您输入的密码是: $user_password（实际配置文件中不会显示此提示）"

# 步骤3: 安装Hysteria服务
echo "开始安装Hysteria服务..."
bash <(curl -fsSL https://get.hy2.sh/)

if [ $? -ne 0 ]; then
    echo "错误: Hysteria安装失败，请检查网络或手动安装。"
    exit 1
fi

echo "Hysteria服务安装完成。"

# 步骤4: 生成自签证书
echo "开始生成自签证书..."
openssl req -x509 -nodes -newkey ec:<(openssl ecparam -name prime256v1) -keyout /etc/hysteria/server.key -out /etc/hysteria/server.crt -subj "/CN=www.bing.com" -days 36500

if [ $? -ne 0 ]; then
    echo "错误: 生成证书失败，请确保openssl已安装。"
    exit 1
fi

# 修改证书文件权限（确保hysteria用户拥有权限）
sudo chown hysteria /etc/hysteria/server.key
sudo chown hysteria /etc/hysteria/server.crt

echo "自签证书生成并权限设置完成。"

# 步骤5: 生成配置文件并覆盖/etc/hysteria/config.yaml
echo "开始生成配置文件..."
cat > /etc/hysteria/config.yaml << EOF
listen: :$user_port
tls:
  cert: /etc/hysteria/server.crt
  key: /etc/hysteria/server.key
auth:
  type: password
  password: $user_password
masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com/
    rewriteHost: true
EOF

if [ $? -ne 0 ]; then
    echo "错误: 生成配置文件失败。"
    exit 1
fi

echo "配置文件已生成并覆盖到/etc/hysteria/config.yaml，使用端口: $user_port。"

# 步骤6: 重启Hysteria服务
echo "重启Hysteria服务..."
systemctl restart hysteria-server.service

if [ $? -ne 0 ]; then
    echo "错误: 服务重启失败，请检查服务状态。"
    exit 1
fi

echo "Hysteria服务已重启。"

# 步骤7: 检查服务状态和端口
echo "检查Hysteria服务状态..."
systemctl status hysteria-server.service --no-pager

echo "检查端口（UDP $user_port）..."
ss -u -l | grep $user_port

echo "安装和配置完成！请验证服务是否正常运行。如果端口未监听，请检查防火墙规则或日志。"
