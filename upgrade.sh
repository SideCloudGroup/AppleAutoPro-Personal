#!/bin/sh
# AppleAutoPro-Personal 更新脚本
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
repo="SideCloudGroup/AppleAutoPro-Personal"
filename="AppleAutoPro-Personal"
if ! command -v unzip &> /dev/null || ! command -v curl &> /dev/null || ! command -v wget &> /dev/null || ! command -v rsync &> /dev/null; then
    echo -e "${YELLOW}缺少必要的工具，正在安装……${NC}"
    if [ -f /etc/debian_version ]; then
        apt update
        apt -y install unzip curl wget jq rsync
    elif [ -f /etc/redhat-release ]; then
        yum -y install unzip curl wget jq rsync
    else
       echo -e "${RED}无法检测到当前系统，已退出${NC}"
       exit;
    fi
fi
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
geo_check
if [ -n "$isCN" ]; then
    LATEST_TAG=$(curl -s "https://ghfast.top/api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
else
    LATEST_TAG=$(curl -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
fi
echo -e "${BLUE}如文件存在改动，一键更新后将会被替换至最新版本，改动将会消失，请注意备份${NC}"
echo -e "${BLUE}If there are changes in the file, it will be replaced with the latest version after one-click update, and the changes will disappear. Please backup.${NC}"
echo -e "${YELLOW}请按回车继续执行更新 | Press enter to continue...${NC}"
read
echo -e "${GREEN}正在升级到最新版本：$LATEST_TAG${NC}"
docker compose down
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
rsync -av --remove-source-files "$filename-4"/ ./
rm -rf "$filename-4"
rm -rf "v4.zip"
unzip -q -o "$filename.zip"
if [ ! -d "$filename" ]; then
    echo -e "${RED}$filename 目录不存在，退出更新……${NC}"
    exit 1
fi
rm -rf ./web/app
rsync -aq --remove-source-files "$filename/" ./web/
rm -rf "$filename"
rm -rf "$filename.zip"
docker compose pull
chmod +x ./data/entrypoint.sh
echo -e "${GREEN}更新完成，请查看更新日志，检查前端配置文件是否需要改动。${NC}"
docker compose pull
docker compose up -d
echo -e "${YELLOW}是否要清理旧镜像？(y/n)${NC}"
read prune_choice
if [ "$prune_choice" = "y" ]; then
    docker image prune -f
    echo -e "${GREEN}旧镜像已清理${NC}"
else
    echo -e "${YELLOW}跳过旧镜像清理${NC}"
fi
echo -e "${GREEN}升级完成！${NC}"
exit 0