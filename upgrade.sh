#!/bin/sh
# AppleAutoPro-Personal 更新脚本
IFS=$'\n\t'
if [ -t 0 ]; then stty erase ^H; fi
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
repo="SideCloudGroup/AppleAutoPro-Personal"
filename="AppleAutoPro-Personal"

check_docker_permission() {
  current_user=$(whoami)
  if [ "$current_user" != "root" ]; then
    if [ "$(uname)" = "Darwin" ]; then
      echo -e "${BLUE}已检测到系统为${YELLOW}macOS${NC}"
      if ! docker info &>/dev/null; then
        echo -e "${RED}当前无法连接到Docker进程${NC}"
        echo -e "${YELLOW}请检查是否已安装Docker Desktop以及Docker Desktop服务是否已启动！${NC}"
        echo -e "${RED}如果您确信Docker Desktop已在运行，请尝试使用root(sudo)运行此脚本！${NC}"
        exit 1
      fi
    else
      echo -e "${BLUE}已检测到系统为${YELLOW}Linux${NC}"
      if ! id -nG "$current_user" | grep -qw docker; then
        echo -e "${RED}当前用户非root且不在docker用户组中，没有使用docker的权限${NC}"
        echo -e "${YELLOW}解决方法：${NC}"
        echo -e "1.${BLUE}将当前用户加入docker用户组并重新进入终端${YELLOW}(sudo gpasswd -a 用户名 docker)${NC}"
        echo -e "2.${BLUE}直接使用root(sudo)运行此脚本！${NC}"
        exit 1
      fi
    fi
  else
    echo -e "${BLUE}已检测到当前用户为${YELLOW}root${NC}"
  fi
}
check_docker_permission
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
    api_list=(
        "https://cloudflare.com/cdn-cgi/trace"
        "https://blog.cloudflare.com/cdn-cgi/trace"
        "https://dash.cloudflare.com/cdn-cgi/trace"
        "https://developers.cloudflare.com/cdn-cgi/trace"
    )
    ua="Mozilla/5.0 (X11; Linux x86_64; rv:60.0) Gecko/20100101 Firefox/81.0"
    isCN="false"
    for url in "${api_list[@]}"; do
        text="$(curl -A "$ua" -m 10 -sSL "$url" 2>/dev/null)" || continue
        [ -z "$text" ] && continue
        location="$(echo "$text" | grep '^loc=' | cut -d'=' -f2)"
        if [ -n "$location" ]; then
            if [ "$location" = "CN" ]; then
                isCN="true"
            else
                isCN="false"
            fi
            break
        else
            if echo "$text" | grep -q 'loc=CN'; then
                isCN="true"
                break
            fi
        fi
    done
}
geo_check
LATEST_TAG=$(curl -m 10 -s "https://api.github.com/repos/$repo/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
if [ -z "$LATEST_TAG" ]; then
    echo -e "${RED}获取版本号失败或超时，请手动输入版本号（例如：4.0.0）：${NC}"
    read manual_tag
    if [[ "$manual_tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        LATEST_TAG="$manual_tag"
    else
        echo -e "${RED}输入的版本号格式不正确，退出脚本${NC}"
        exit 1
    fi
fi
echo -e "${BLUE}如文件存在改动，一键更新后将会被替换至最新版本，改动将会消失，请注意备份${NC}"
echo -e "${BLUE}If there are changes in the file, it will be replaced with the latest version after one-click update, and the changes will disappear. Please backup.${NC}"
echo -e "${GREEN}当前最新版本：$LATEST_TAG | Current latest version: $LATEST_TAG${NC}"
echo -e "${YELLOW}请按回车继续执行更新 | Press enter to continue...${NC}"
read
echo -e "${GREEN}正在升级到最新版本：$LATEST_TAG${NC}"
if [ "$isCN" = "true" ]; then
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
rsync -av --remove-source-files --exclude 'docker-compose.yml' --exclude 'Caddyfile' "$filename-4"/ ./
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
docker compose down
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