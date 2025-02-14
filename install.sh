#!/bin/sh
# TronPower 安装脚本
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
repo="SideCloudGroup/AppleAutoPro-Personal"
filename="AppleAutoPro-Personal"

geo_check() {
    api_list="https://blog.cloudflare.com/cdn-cgi/trace https://dash.cloudflare.com/cdn-cgi/trace https://developers.cloudflare.com/cdn-cgi/trace"
    ua="Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0"
    set -- "$api_list"
    for url in $api_list; do
        text="$(curl -A "$ua" -m 10 -s "$url")"
        endpoint="$(echo "$text" | sed -n 's/.*h=\([^ ]*\).*/\1/p')"
        if echo "$text" | grep -qw 'CN'; then
            isCN=true
            break
        elif echo "$url" | grep -q "$endpoint"; then
            break
        fi
    done
}

# is cn
if [ -n "$isCN" ]; then
    LATEST_TAG=$(curl -s "https://ghfast.top/api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
else
    LATEST_TAG=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
fi

echo -e "${YELLOW}请输入安装路径（回车默认安装到/opt/AppleAutoPro-Personal）:${NC}"
read install_path
install_path=${install_path:-/opt/AppleAutoPro-Personal}

if [ -d "$install_path" ]; then
    echo -e "${RED}$install_path 文件夹已存在，退出脚本${NC}"
    exit 1
fi

echo -e "${BLUE}检查并安装必要的软件包...${NC}"

if docker >/dev/null 2>&1; then
    echo -e "${GREEN}Docker已安装${NC}"
else
    echo -e "${YELLOW}Docker未安装，开始安装……${NC}"
    if [ -n "$isCN" ]; then
        bash <(curl -sSL https://linuxmirrors.cn/docker.sh) --source-registry "https://docker.1panel.live" --install-latest true --ignore-backup-tips
    else
        curl -fsSL https://get.docker.com | bash
    fi
    systemctl enable docker && systemctl restart docker
    echo -e "${GREEN}Docker安装完成${NC}"
fi
if ! docker >/dev/null 2>&1; then
    echo -e "${RED}Docker安装失败，请检查错误信息${NC}"
    exit 1
fi
if ! unzip -v >/dev/null 2>&1; then
    echo -e "${YELLOW}unzip未安装，开始安装……${NC}"
    apt-get update && apt-get install -y unzip
    echo -e "${GREEN}unzip安装完成${NC}"
fi
if ! wget --version >/dev/null 2>&1; then
    echo -e "${YELLOW}wget未安装，开始安装……${NC}"
    apt-get update && apt-get install -y wget
    echo -e "${GREEN}wget安装完成${NC}"
fi
cd $install_path
if [ -n "$isCN" ]; then
    wget -T 20 -q "https://ghfast.top/github.com/$repo/archive/refs/heads/v4.zip" -O "v4.zip"
    wget -T 20 -q "https://ghfast.top/github.com/$repo/releases/download/$LATEST_TAG/$filename.zip" -O "$filename.zip"
else
    wget -T 20 -q "https://github.com/$repo/archive/refs/heads/v4.zip" -O "v4.zip"
    wget -T 20 -q "https://github.com/$repo/releases/download/$LATEST_TAG/$filename.zip" -O "$filename.zip"
fi
if [ $? -ne 0 ]; then
    echo -e "${RED}wget失败或超时，退出程序${NC}"
    exit 1
fi
unzip -q -o "v4.zip"
mv "$filename-v4"/* ./
rm -rf "$filename-v4"
rm -rf "$filename"
unzip -q -o "$filename.zip"
if [ ! -d "$filename" ]; then
    echo -e "${RED}$filename 目录不存在，退出更新……${NC}"
    exit 1
fi
mv "$filename" web
rm -rf "$filename.zip"
docker compose pull
mv .example.env .env
echo -e "${GREEN}下载完成！请继续按照教程完成接下来的步骤${NC}"
exit 0